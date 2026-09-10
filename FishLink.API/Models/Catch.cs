using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class Catch
{
    [Key]
    public int Id { get; set; }

    public int FishermanId { get; set; }
    [ForeignKey("FishermanId")]
    public User? Fisherman { get; set; }

    [Required]
    public string FishSpecies { get; set; } = string.Empty;

    public decimal QuantityKg { get; set; }
    
    public decimal AskingPricePerKg { get; set; }

    public DateTime CatchTime { get; set; }

    public string Location { get; set; } = string.Empty;

    public string PhotoUrl { get; set; } = string.Empty;

    public string Status { get; set; } = "Listed"; // Listed, Bidding, PendingApproval, Sold, Rejected

    public int QualityScore { get; set; } = 0; // Filled by Quality Agent
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
