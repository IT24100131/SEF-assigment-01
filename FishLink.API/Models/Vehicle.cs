using System.ComponentModel.DataAnnotations;

namespace FishLink.API.Models;

public class Vehicle
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string VehicleCode { get; set; } = string.Empty;  // V01, V02...

    public string DriverName   { get; set; } = string.Empty;
    public decimal CapacityKg  { get; set; }
    public string Status       { get; set; } = "Available"; // Available, Busy, Maintenance
    public string LicensePlate { get; set; } = string.Empty;
    public string VehicleType  { get; set; } = "Refrigerated Truck";
    public string CurrentLocation { get; set; } = "Negombo";
    public bool   HasColdChain { get; set; } = true;
    public DateTime UpdatedAt  { get; set; } = DateTime.UtcNow;
}
