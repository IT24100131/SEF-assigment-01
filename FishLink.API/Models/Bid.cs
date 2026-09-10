using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class Bid
{
    [Key]
    public int Id { get; set; }

    public int CatchId { get; set; }
    [ForeignKey("CatchId")]
    public Catch? Catch { get; set; }

    public int BuyerId { get; set; }
    [ForeignKey("BuyerId")]
    public User? Buyer { get; set; }

    public decimal BidPricePerKg { get; set; }

    public DateTime BidTime { get; set; } = DateTime.UtcNow;

    public string Status { get; set; } = "Pending"; // Pending, Accepted, Rejected
}
