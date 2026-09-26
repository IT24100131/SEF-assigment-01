using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class DeliveryPlan
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string PlanId      { get; set; } = Guid.NewGuid().ToString(); // unique plan ID

    public int    CatchId     { get; set; }   // linked catch
    public int?   BidId       { get; set; }   // linked bid (when bid accepted)

    // Assigned resources
    public string VehicleCode    { get; set; } = string.Empty;
    public string DriverCode     { get; set; } = string.Empty;
    public string ColdStorageCode { get; set; } = string.Empty;

    // Route
    public string PickupLocation  { get; set; } = string.Empty;
    public string DeliveryLocation { get; set; } = string.Empty;
    public string SelectedRoute   { get; set; } = string.Empty;   // "Route A" / "Route B"
    public decimal DistanceKm     { get; set; }
    public int     EstimatedMinutes { get; set; }

    // Schedule
    public DateTime? PickupTime   { get; set; }
    public DateTime? EstimatedETA { get; set; }
    public DateTime? DeliveryDeadline { get; set; }

    // Status
    public string Status { get; set; } = "PendingApproval"; // PendingApproval, Scheduled, InTransit, Delivered, Rejected

    // AI Agent output
    public string AgentReasoning  { get; set; } = string.Empty;  // why these choices
    public string WeatherNote     { get; set; } = string.Empty;
    public string AdminNote       { get; set; } = string.Empty;

    public DateTime CreatedAt     { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt     { get; set; } = DateTime.UtcNow;
}
