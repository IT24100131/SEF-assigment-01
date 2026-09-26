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
}
