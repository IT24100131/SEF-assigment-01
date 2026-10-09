using FishLink.API.Data;
using FishLink.API.Models;
using Microsoft.EntityFrameworkCore;

namespace FishLink.API.Services;

public class UserService : IUserService
{
    private readonly ApplicationDbContext _db;
    private readonly ILogger<UserService> _logger;

    public UserService(ApplicationDbContext db, ILogger<UserService> logger)
    {
        _db     = db;
        _logger = logger;
    }

    public async Task<PagedResult<User>> GetUsersAsync(UserQueryParams q)
    {
        var query = _db.Users.AsQueryable();

        // Search by name or email
        if (!string.IsNullOrWhiteSpace(q.Search))
        {
            var s = q.Search.ToLower();
            query = query.Where(u =>
                u.FullName.ToLower().Contains(s) ||
                u.Email.ToLower().Contains(s));
        }

        // Filter by role
        if (!string.IsNullOrWhiteSpace(q.Role))
            query = query.Where(u => u.Role == q.Role);

        // Sort
        query = (q.SortBy.ToLower(), q.SortOrder.ToLower()) switch
        {
            ("name",  "asc")  => query.OrderBy(u => u.FullName),
            ("name",  _)      => query.OrderByDescending(u => u.FullName),
            ("email", "asc")  => query.OrderBy(u => u.Email),
            ("email", _)      => query.OrderByDescending(u => u.Email),
            ("role",  "asc")  => query.OrderBy(u => u.Role),
            ("role",  _)      => query.OrderByDescending(u => u.Role),
            (_,       "asc")  => query.OrderBy(u => u.CreatedAt),
            _                 => query.OrderByDescending(u => u.CreatedAt),
        };

        var total = await query.CountAsync();
        var page  = Math.Max(1, q.Page);
        var size  = Math.Clamp(q.PageSize, 1, 100);
        var items = await query
            .Select(u => new User {
                Id        = u.Id,
                FullName  = u.FullName,
                Email     = u.Email,
                Role      = u.Role,
                CreatedAt = u.CreatedAt,
                // Never expose PasswordHash
                PasswordHash = string.Empty,
            })
            .Skip((page - 1) * size)
            .Take(size)
            .ToListAsync();

        return new PagedResult<User> { Items = items, TotalCount = total, Page = page, PageSize = size };
    }

    public async Task<User?> GetByIdAsync(int id)
    {
        var u = await _db.Users.FindAsync(id);
        if (u != null) u.PasswordHash = string.Empty; // never expose hash
        return u;
    }

    public async Task<bool> UpdateRoleAsync(int id, string role)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) throw new KeyNotFoundException($"User {id} not found.");
        u.Role = role;
        await _db.SaveChangesAsync();
        _logger.LogInformation("User {Id} role updated to {Role}", id, role);
        return true;
    }

    public async Task<bool> UpdateProfileAsync(int id, string fullName, string? currentPassword, string? newPassword)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) throw new KeyNotFoundException($"User {id} not found.");

        if (!string.IsNullOrWhiteSpace(fullName))
            u.FullName = fullName.Trim();

        if (!string.IsNullOrWhiteSpace(newPassword))
        {
            if (string.IsNullOrWhiteSpace(currentPassword))
                throw new ArgumentException("Current password is required to change password.");

            bool currentValid = false;
            try
            {
                currentValid = BCrypt.Net.BCrypt.Verify(currentPassword, u.PasswordHash);
            }
            catch
            {
                currentValid = u.PasswordHash == currentPassword;
            }

            if (!currentValid)
                throw new ArgumentException("Current password is incorrect.");

            if (newPassword.Length < 6)
                throw new ArgumentException("New password must be at least 6 characters long.");

            u.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        }

        await _db.SaveChangesAsync();
        _logger.LogInformation("Profile updated for User {Id}", id);
        return true;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) throw new KeyNotFoundException($"User {id} not found.");

        // Remove related preferences
        var prefs = await _db.BuyerPreferences.Where(p => p.BuyerId == id).ToListAsync();
        if (prefs.Count > 0) _db.BuyerPreferences.RemoveRange(prefs);

        // Remove related bids
        var bids = await _db.Bids.Where(b => b.BuyerId == id).ToListAsync();
        if (bids.Count > 0) _db.Bids.RemoveRange(bids);

        // Remove related catches (for fishermen) and bids on those catches
        var catches = await _db.Catches.Where(c => c.FishermanId == id).ToListAsync();
        if (catches.Count > 0)
        {
            var catchIds = catches.Select(c => c.Id).ToList();
            var catchBids = await _db.Bids.Where(b => catchIds.Contains(b.CatchId)).ToListAsync();
            if (catchBids.Count > 0) _db.Bids.RemoveRange(catchBids);
            _db.Catches.RemoveRange(catches);
        }

        _db.Users.Remove(u);
        await _db.SaveChangesAsync();
        _logger.LogInformation("User {Id} and associated records deleted", id);
        return true;
    }
}
