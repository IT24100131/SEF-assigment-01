using System.ComponentModel.DataAnnotations;

namespace FishLink.API.Models;

public class User
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string FullName { get; set; } = string.Empty;

    [Required]
    public string Email { get; set; } = string.Empty;

    public string PasswordHash { get; set; } = string.Empty;

    [Required]
    public string Role { get; set; } = string.Empty; // Fisherman, Buyer, Admin, Logistics, Quality

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
