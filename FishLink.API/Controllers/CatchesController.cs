using FishLink.API.Data;
using FishLink.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FishLink.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CatchesController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CatchesController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetCatches()
    {
        var catches = await _context.Catches.Include(c => c.Fisherman).ToListAsync();
        return Ok(catches);
    }

    [HttpPost]
    [Authorize(Roles = "Fisherman")]
    public async Task<IActionResult> CreateCatch([FromBody] Catch newCatch)
    {
        var userId = int.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        newCatch.FishermanId = userId;
        
        _context.Catches.Add(newCatch);
        await _context.SaveChangesAsync();

        // TODO: Call Python Agentic AI Subsystem to start the workflow
        // var agentState = new AgentWorkflowState { CatchId = newCatch.Id, CurrentAgent = "Planning" };
        // _context.AgentWorkflows.Add(agentState);
        // await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetCatches), new { id = newCatch.Id }, newCatch);
    }
}
