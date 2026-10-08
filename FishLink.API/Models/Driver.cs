using System.ComponentModel.DataAnnotations;

namespace FishLink.API.Models;

public class Driver
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string DriverCode   { get; set; } = string.Empty;  // D01, D02...
    public string FullName     { get; set; } = string.Empty;
    public string Phone        { get; set; } = string.Empty;
    public string Status       { get; set; } = "Available";   // Available, Busy, OffDuty
    public string AvailableFrom { get; set; } = "06:00";      // HH:mm
    public string AvailableTo   { get; set; } = "18:00";
    public string CurrentLocation { get; set; } = "Negombo";
    public int    TotalDeliveries { get; set; } = 0;
    public DateTime UpdatedAt  { get; set; } = DateTime.UtcNow;
}
