using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace FishLink.API.Models;

public class Order
{
    [Key]
    public int Id { get; set; }

    public int BidId { get; set; }
    [ForeignKey("BidId")]
    public Bid? Bid { get; set; }

    public decimal TotalAmount { get; set; }

    public string Status { get; set; } = "Created"; // Created, InTransit, Delivered, Cancelled
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
