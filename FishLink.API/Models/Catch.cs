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

    public decimal QuantityKg { get; set; }          // Declared weight by fisherman

    public decimal AskingPricePerKg { get; set; }

    public DateTime CatchTime { get; set; }

    public string Location { get; set; } = string.Empty;

    public string PhotoUrl { get; set; } = string.Empty;

    public string Status { get; set; } = "Draft";   // Draft, Published, Bidding, PendingApproval, Sold, Cancelled, Expired

    public int QualityScore { get; set; } = 0;       // Filled by Quality Agent (0–100)

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // ── Structured Quality & Fraud Validation fields ──────────────────────────

    /// Physical weight verified by inspector / pier officer (kg)
    public decimal VerifiedWeightKg { get; set; } = 0;

    /// Declared quality grade by fisherman: A+, A, B, C
    public string DeclaredQualityGrade { get; set; } = string.Empty;

    /// Physical inspection result: Passed, Failed, Pending
    public string InspectionResult { get; set; } = "Pending";

    /// Catch date & time (when fish was actually caught)
    public DateTime? CatchDateTime { get; set; }

    /// Fraud risk level assigned by agent: Low, Medium, High
    public string FraudRisk { get; set; } = "Unassessed";

    /// Weight discrepancy (%) calculated by agent
    public decimal WeightDiscrepancyPct { get; set; } = 0;

    /// Agent's full validation summary (multi-step analysis result)
    public string ValidationSummary { get; set; } = string.Empty;

    /// Flag for admin review required
    public bool RequiresAdminReview { get; set; } = false;

    /// Seller note / fisherman's own description
    public string SellerNote { get; set; } = string.Empty;
}
