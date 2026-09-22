using FishLink.API.Data;
using FishLink.API.Models;
using FishLink.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FishLink.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class LogisticsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IWeatherService      _weather;
    private readonly ILogger<LogisticsController> _logger;

    public LogisticsController(
        ApplicationDbContext context,
        IWeatherService weather,
        ILogger<LogisticsController> logger)
    {
        _context = context;
        _weather = weather;
        _logger  = logger;
    }

    // ── Tool endpoints (called by AI Agent & Dashboard) ─────────────────────

    /// GET /api/Logistics/vehicles — all vehicles
    [HttpGet("vehicles")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAllVehicles()
    {
        var vehicles = await _context.Vehicles
            .OrderBy(v => v.VehicleCode)
            .ToListAsync();
        return Ok(vehicles);
    }

    /// GET /api/Logistics/vehicles/available?capacityKg=100
    [HttpGet("vehicles/available")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAvailableVehicles([FromQuery] decimal capacityKg = 0)
    {
        var vehicles = await _context.Vehicles
            .Where(v => v.Status == "Available" &&
                        (capacityKg == 0 || v.CapacityKg >= capacityKg))
            .OrderBy(v => v.CapacityKg)
            .ToListAsync();
        return Ok(vehicles);
    }

    /// GET /api/Logistics/drivers — all drivers
    [HttpGet("drivers")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAllDrivers()
    {
        var drivers = await _context.Drivers
            .OrderBy(d => d.DriverCode)
            .ToListAsync();
        return Ok(drivers);
    }

    /// GET /api/Logistics/drivers/available
    [HttpGet("drivers/available")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAvailableDrivers()
    {
        var drivers = await _context.Drivers
            .Where(d => d.Status == "Available")
            .OrderBy(d => d.DriverCode)
            .ToListAsync();
        return Ok(drivers);
    }

    /// GET /api/Logistics/storage — all cold storage
    [HttpGet("storage")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAllColdStorage()
    {
        var storages = await _context.ColdStorages
            .OrderBy(s => s.StorageCode)
            .ToListAsync();
        return Ok(storages);
    }

    /// GET /api/Logistics/storage/available?capacityKg=100
    [HttpGet("storage/available")]
    [AllowAnonymous]
    public async Task<IActionResult> GetAvailableColdStorage([FromQuery] decimal capacityKg = 0)
    {
        var storages = await _context.ColdStorages
            .Where(s => s.Status == "Available" &&
                        (capacityKg == 0 || (s.TotalCapacityKg - s.UsedCapacityKg) >= capacityKg))
            .OrderBy(s => s.TemperatureCelsius)
            .ToListAsync();
        return Ok(storages);
    }

    /// GET /api/Logistics/route?from=Negombo&to=Colombo
    /// Returns route options with distance + estimated time.
    /// Uses hardcoded Sri Lanka city pairs (no external Maps API needed).
    [HttpGet("route")]
    [AllowAnonymous]
    public IActionResult GetRoute([FromQuery] string from, [FromQuery] string to)
    {
        var routes = BuildRoutes(from?.ToLower() ?? "", to?.ToLower() ?? "");
        return Ok(new { from, to, routes });
    }

    /// GET /api/Logistics/weather?location=Negombo
    /// Returns real weather via OpenWeatherMap (or simulation fallback).
    [HttpGet("weather")]
    [AllowAnonymous]
    public async Task<IActionResult> GetWeather([FromQuery] string location = "Negombo")
    {
        _logger.LogInformation("Logistics weather request for {Location}", location);
        var result = await _weather.GetWeatherAsync(location);
        return Ok(result);
    }

    // ── Delivery Plan CRUD ────────────────────────────────────────────────────

    /// POST /api/Logistics/plans — AI Agent creates a plan
    [HttpPost("plans")]
    [AllowAnonymous]   // AI agent calls this
    public async Task<IActionResult> CreateDeliveryPlan([FromBody] DeliveryPlan plan)
    {
        plan.CreatedAt = DateTime.UtcNow;
        plan.UpdatedAt = DateTime.UtcNow;
        plan.Status    = "PendingApproval";
        plan.PlanId    = $"PLAN-{plan.CatchId}-{DateTime.UtcNow:HHmmss}";

        _context.DeliveryPlans.Add(plan);
        await _context.SaveChangesAsync();
        return Ok(plan);
    }

    /// GET /api/Logistics/plans — all plans (admin & logistics)
    [HttpGet("plans")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPlans()
    {
        var plans = await _context.DeliveryPlans
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();
        return Ok(plans);
    }

    /// GET /api/Logistics/plans/pending — plans awaiting admin approval
    [HttpGet("plans/pending")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPendingPlans()
    {
        var plans = await _context.DeliveryPlans
            .Where(p => p.Status == "PendingApproval")
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();
        return Ok(plans);
    }

    /// GET /api/Logistics/plans/catch/{catchId}
    [HttpGet("plans/catch/{catchId}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPlanForCatch(int catchId)
    {
        var plan = await _context.DeliveryPlans
            .Where(p => p.CatchId == catchId)
            .OrderByDescending(p => p.CreatedAt)
            .FirstOrDefaultAsync();
        if (plan == null) return NotFound("No delivery plan for this catch.");
        return Ok(plan);
    }

    /// PATCH /api/Logistics/plans/{id}/approve
    [HttpPatch("plans/{id}/approve")]
    [Authorize(Roles = "Admin,Logistics")]
    public async Task<IActionResult> ApprovePlan(int id, [FromBody] ApproveRequest? req = null)
    {
        var plan = await _context.DeliveryPlans.FindAsync(id);
        if (plan == null) return NotFound();

        plan.Status    = "Scheduled";
        plan.AdminNote = req?.Note ?? string.Empty;
        plan.UpdatedAt = DateTime.UtcNow;

        // Mark vehicle and driver as Busy
        var vehicle = await _context.Vehicles.FirstOrDefaultAsync(v => v.VehicleCode == plan.VehicleCode);
        if (vehicle != null) { vehicle.Status = "Busy"; vehicle.UpdatedAt = DateTime.UtcNow; }

        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.DriverCode == plan.DriverCode);
        if (driver != null) { driver.Status = "Busy"; driver.UpdatedAt = DateTime.UtcNow; }

        // Reserve cold storage
        if (!string.IsNullOrEmpty(plan.ColdStorageCode))
        {
            var storage = await _context.ColdStorages
                .FirstOrDefaultAsync(s => s.StorageCode == plan.ColdStorageCode);
            if (storage != null)
            {
                var catchRecord = await _context.Catches.FindAsync(plan.CatchId);
                if (catchRecord != null)
                    storage.UsedCapacityKg += catchRecord.QuantityKg;
                storage.UpdatedAt = DateTime.UtcNow;
            }
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Delivery plan approved and scheduled.", planId = plan.PlanId, status = plan.Status });
    }

    /// PATCH /api/Logistics/plans/{id}/reject
    [HttpPatch("plans/{id}/reject")]
    [Authorize(Roles = "Admin,Logistics")]
    public async Task<IActionResult> RejectPlan(int id, [FromBody] ApproveRequest? req = null)
    {
        var plan = await _context.DeliveryPlans.FindAsync(id);
        if (plan == null) return NotFound();

        plan.Status    = "Rejected";
        plan.AdminNote = req?.Note ?? string.Empty;
        plan.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return Ok(new { message = "Delivery plan rejected.", planId = plan.PlanId });
    }

    /// PATCH /api/Logistics/plans/{id}/complete — mark delivery done
    [HttpPatch("plans/{id}/complete")]
    [Authorize(Roles = "Admin,Logistics")]
    public async Task<IActionResult> CompletePlan(int id)
    {
        var plan = await _context.DeliveryPlans.FindAsync(id);
        if (plan == null) return NotFound();
        plan.Status    = "Delivered";
        plan.UpdatedAt = DateTime.UtcNow;

        // Free up vehicle + driver
        var vehicle = await _context.Vehicles.FirstOrDefaultAsync(v => v.VehicleCode == plan.VehicleCode);
        if (vehicle != null) { vehicle.Status = "Available"; vehicle.UpdatedAt = DateTime.UtcNow; }
        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.DriverCode == plan.DriverCode);
        if (driver != null) { driver.Status = "Available"; driver.TotalDeliveries++; driver.UpdatedAt = DateTime.UtcNow; }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Delivery marked complete.", planId = plan.PlanId });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static List<object> BuildRoutes(string from, string to)
    {
        // Lookup table for common Sri Lanka city pairs
        var key = $"{from}→{to}";
        return key switch
        {
            "negombo→colombo" or "colombo→negombo" => new List<object> {
                new { routeName="Route A (Colombo-Katunayake Expressway)", distanceKm=38, estimatedMinutes=55,  notes="Expressway — fast but toll" },
                new { routeName="Route B (Via Wattala)",                   distanceKm=42, estimatedMinutes=75,  notes="No toll — moderate traffic" },
            },
            "negombo→kandy" or "kandy→negombo" => new List<object> {
                new { routeName="Route A (Colombo-Kandy Road A1)", distanceKm=121, estimatedMinutes=160, notes="Main highway" },
                new { routeName="Route B (Via Minuwangoda)",       distanceKm=115, estimatedMinutes=150, notes="Shorter but narrower" },
            },
            "negombo→galle" or "galle→negombo" => new List<object> {
                new { routeName="Route A (Southern Expressway)", distanceKm=148, estimatedMinutes=120, notes="Expressway — fast" },
                new { routeName="Route B (Coastal Road)",        distanceKm=162, estimatedMinutes=180, notes="Scenic but slow" },
            },
            _ => new List<object> {
                new { routeName="Route A (Direct)", distanceKm=50,  estimatedMinutes=90,  notes="Estimated — actual route unknown" },
                new { routeName="Route B (Alternate)", distanceKm=60, estimatedMinutes=110, notes="Alternative route" },
            }
        };
    }

    private static object SimulateWeather(string location)
    {
        // Deterministic simulation based on current hour
        var hour = DateTime.UtcNow.AddHours(5.5).Hour; // Sri Lanka time
        var isRainy = hour >= 14 && hour <= 17;         // afternoon rain common in SL

        return new
        {
            location,
            condition       = isRainy ? "Heavy Rain" : "Clear",
            temperatureCelsius = isRainy ? 27 : 32,
            windSpeedKmh    = isRainy ? 25 : 10,
            rainExpected    = isRainy,
            rainWindow      = isRainy ? $"{hour:D2}:00 – {hour + 2:D2}:00" : "None",
            drivingRisk     = isRainy ? "Moderate — allow extra 20 min" : "Low",
            note            = isRainy
                ? "Rain expected. Consider Route B with lower flood risk."
                : "Good driving conditions.",
            source          = "Simulated (replace with OpenWeatherMap API)",
        };
    }
}

public class ApproveRequest
{
    public string? Note { get; set; }
}
