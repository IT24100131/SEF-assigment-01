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

    public async Task<bool> DeleteAsync(int id)
    {
        var u = await _db.Users.FindAsync(id);
        if (u == null) throw new KeyNotFoundException($"User {id} not found.");
        _db.Users.Remove(u);
        await _db.SaveChangesAsync();
        _logger.LogInformation("User {Id} deleted", id);
        return true;
    }
}
