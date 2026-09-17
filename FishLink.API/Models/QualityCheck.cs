using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class QualityCheck
{
    [Key]
    public int Id { get; set; }

    public int CatchId { get; set; }
    [ForeignKey("CatchId")]
    public Catch? Catch { get; set; }

    public int InspectorId { get; set; }
    [ForeignKey("InspectorId")]
    public User? Inspector { get; set; }

    public decimal VerifiedWeightKg { get; set; }

    public string Notes { get; set; } = string.Empty;

    public bool IsPassed { get; set; }

    public DateTime InspectedAt { get; set; } = DateTime.UtcNow;
}
