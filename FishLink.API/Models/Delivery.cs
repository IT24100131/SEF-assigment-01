using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class Delivery
{
    [Key]
    public int Id { get; set; }

    public int OrderId { get; set; }
    [ForeignKey("OrderId")]
    public Order? Order { get; set; }

    public string VehicleAssignment { get; set; } = string.Empty;

    public string DriverName { get; set; } = string.Empty;

    public string RouteCoordinates { get; set; } = string.Empty; // JSON of route

    public DateTime EstimatedDeliveryTime { get; set; }
    
    public string Status { get; set; } = "Scheduled"; // Scheduled, PickedUp, InTransit, Delivered

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
