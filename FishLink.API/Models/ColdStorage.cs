using System.ComponentModel.DataAnnotations;

namespace FishLink.API.Models;

public class ColdStorage
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string StorageCode      { get; set; } = string.Empty;  // C01, C02...
    public string Name             { get; set; } = string.Empty;
    public string Location         { get; set; } = string.Empty;
    public decimal TotalCapacityKg { get; set; }
    public decimal UsedCapacityKg  { get; set; } = 0;
    public decimal TemperatureCelsius { get; set; } = 4;
    public string Status           { get; set; } = "Available"; // Available, Full, Maintenance
    public DateTime UpdatedAt      { get; set; } = DateTime.UtcNow;

    // Calculated
    public decimal AvailableCapacityKg => TotalCapacityKg - UsedCapacityKg;
}
