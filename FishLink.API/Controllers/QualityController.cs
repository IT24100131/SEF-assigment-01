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
public class QualityController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public QualityController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpPost("inspect/{catchId}")]
    [Authorize(Roles = "Quality")]
    public async Task<IActionResult> SubmitInspection(int catchId, [FromBody] QualityCheck qualityCheck)
    {
        var inspectorId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value!);
        qualityCheck.InspectorId = inspectorId;
        qualityCheck.CatchId = catchId;
        qualityCheck.InspectedAt = DateTime.UtcNow;

        _context.QualityChecks.Add(qualityCheck);
        
        var fishCatch = await _context.Catches.FindAsync(catchId);
        if (fishCatch != null)
        {
            fishCatch.QualityScore = qualityCheck.IsPassed ? 100 : 0; // Simple logic
        }

        await _context.SaveChangesAsync();

        // Trigger Quality Validation Agent
        var workflow = await _context.AgentWorkflows.FirstOrDefaultAsync(w => w.CatchId == catchId);
        if (workflow != null)
        {
            workflow.CurrentAgent = "QualityValidation";
            workflow.LastUpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        return Ok(qualityCheck);
    }
}
