using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class BuyerPreference
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int BuyerId { get; set; }
    [ForeignKey("BuyerId")]
    public User? Buyer { get; set; }

    // What species does this buyer want?
    public string PreferredSpecies { get; set; } = string.Empty; // e.g. "Tuna (Yellowfin)"

    // Quantity range they typically need
    public decimal MinQuantityKg { get; set; } = 0;
    public decimal MaxQuantityKg { get; set; } = 99999;

    // Maximum price they are willing to pay
    public decimal MaxPricePerKg { get; set; } = 99999;

    // Preferred pickup / delivery city
    public string PreferredCity { get; set; } = string.Empty;

    // Free-text notes (e.g. "Fresh only, no frozen")
    public string Notes { get; set; } = string.Empty;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
