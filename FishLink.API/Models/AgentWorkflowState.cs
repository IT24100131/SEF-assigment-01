using System.ComponentModel.DataAnnotations;

namespace FishLink.API.Models;

public class AgentWorkflowState
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string WorkflowId { get; set; } = Guid.NewGuid().ToString(); // To match cross-platform reference

    public int CatchId { get; set; }

    public string CurrentAgent { get; set; } = string.Empty; // e.g., Planning, Quality, Logistics

    public string Status { get; set; } = "InProgress"; // InProgress, PendingApproval, Approved, Rejected, Failed

    public string RecommendationSummary { get; set; } = string.Empty; // Store JSON or Text

    public DateTime LastUpdatedAt { get; set; } = DateTime.UtcNow;
}
