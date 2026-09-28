using FishLink.API.Data;
using FishLink.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace FishLink.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BidsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public BidsController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet("catch/{catchId}")]
    public async Task<IActionResult> GetBidsForCatch(int catchId)
    {
        var bids = await _context.Bids
            .Include(b => b.Buyer)
            .Where(b => b.CatchId == catchId)
            .ToListAsync();
        
        return Ok(bids);
    }

    [HttpPost]
    [Authorize(Roles = "Buyer")]
    public async Task<IActionResult> PlaceBid([FromBody] Bid newBid)
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value!);
        newBid.BuyerId = userId;
        newBid.BidTime = DateTime.UtcNow;
        newBid.Status = "Pending";

        var fishCatch = await _context.Catches.FindAsync(newBid.CatchId);
        if (fishCatch == null) return NotFound("Catch not found");

        _context.Bids.Add(newBid);
        await _context.SaveChangesAsync();

        // Update catch status to Bidding
        fishCatch.Status = "Bidding";
        await _context.SaveChangesAsync();

        // Update the Agent Workflow State + call AI webhook
        var workflow = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.CatchId == fishCatch.Id);
        if (workflow != null)
        {
            workflow.CurrentAgent = "BuyerMatching";
            workflow.LastUpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            // Call Python AI agent webhook
            try
            {
                using var http = new System.Net.Http.HttpClient { Timeout = TimeSpan.FromSeconds(5) };
                await http.PostAsJsonAsync("http://localhost:8000/api/workflow/start", new
                {
                    workflow_id  = workflow.WorkflowId,
                    catch_id     = fishCatch.Id,
                    fisherman_id = fishCatch.FishermanId,
                    quantity_kg  = (double)fishCatch.QuantityKg,
                    asking_price = (double)fishCatch.AskingPricePerKg,
                    fish_species = fishCatch.FishSpecies,
                });
            }
            catch { /* AI agent offline — non-blocking */ }
        }

        return CreatedAtAction(nameof(GetBidsForCatch), new { catchId = newBid.CatchId }, newBid);
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMyBids()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null) return Unauthorized();
        var userId = int.Parse(userIdClaim);

        var bids = await _context.Bids
            .Include(b => b.Catch)
            .Where(b => b.BuyerId == userId)
            .OrderByDescending(b => b.BidTime)
            .Select(b => new
            {
                b.Id,
                b.CatchId,
                b.BidPricePerKg,
                b.BidTime,
                b.Status,
                Species = b.Catch != null ? b.Catch.FishSpecies : "Unknown",
                QuantityKg = b.Catch != null ? b.Catch.QuantityKg : 0,
                Location = b.Catch != null ? b.Catch.Location : "",
                AskingPrice = b.Catch != null ? b.Catch.AskingPricePerKg : 0,
                QualityGrade = b.Catch != null ? (b.Catch.QualityScore >= 85 ? "A" : b.Catch.QualityScore >= 70 ? "B" : "C") : "A",
                CurrentHighest = _context.Bids.Where(x => x.CatchId == b.CatchId).Max(x => (decimal?)x.BidPricePerKg) ?? b.BidPricePerKg,
            })
            .ToListAsync();

        return Ok(bids);
    }

    [HttpPatch("{id}/accept")]
    [Authorize(Roles = "Fisherman,Admin")]
    public async Task<IActionResult> AcceptBid(int id)
    {
        var bid = await _context.Bids.Include(b => b.Catch).FirstOrDefaultAsync(b => b.Id == id);
        if (bid == null) return NotFound("Bid not found");

        bid.Status = "Accepted";

        // Mark other bids for this catch as Rejected / Lost
        var otherBids = await _context.Bids
            .Where(b => b.CatchId == bid.CatchId && b.Id != id)
            .ToListAsync();
        foreach (var ob in otherBids)
        {
            ob.Status = "Lost";
        }

        // Create Order
        var total = bid.BidPricePerKg * (bid.Catch?.QuantityKg ?? 1);
        var order = new Order
        {
            BidId = bid.Id,
            TotalAmount = total,
            Status = "Created",
            CreatedAt = DateTime.UtcNow,
        };
        _context.Orders.Add(order);

        if (bid.Catch != null)
        {
            bid.Catch.Status = "Sold";
        }

        await _context.SaveChangesAsync();

        // Trigger Logistics Agent (via workflow record & internal HTTP)
        try
        {
            var workflow = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.CatchId == bid.CatchId);
            if (workflow != null)
            {
                workflow.CurrentAgent = "Logistics";
                workflow.LastUpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }

            using var http = new System.Net.Http.HttpClient { Timeout = TimeSpan.FromSeconds(3) };
            await http.PostAsJsonAsync("http://localhost:8000/api/logistics/plan", new
            {
                order_id = order.Id,
                catch_id = bid.CatchId,
                buyer_id = bid.BuyerId,
                pickup_location = bid.Catch?.Location ?? "Negombo",
                weight_kg = (double)(bid.Catch?.QuantityKg ?? 100),
            });
        }
        catch { /* logistics agent trigger non-blocking */ }

        return Ok(new
        {
            message = "Bid accepted successfully! Order created and Logistics Agent triggered.",
            orderId = order.Id,
            bidId = bid.Id,
            status = "Accepted",
            totalAmount = total,
        });
    }

    [HttpPatch("{id}/reject")]
    [Authorize(Roles = "Fisherman,Admin")]
    public async Task<IActionResult> RejectBid(int id)
    {
        var bid = await _context.Bids.FindAsync(id);
        if (bid == null) return NotFound("Bid not found");

        bid.Status = "Rejected";
        await _context.SaveChangesAsync();

        return Ok(new { message = "Bid rejected.", bidId = id, status = "Rejected" });
    }
}
