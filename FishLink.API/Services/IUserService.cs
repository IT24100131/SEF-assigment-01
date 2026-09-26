using FishLink.API.Models;

namespace FishLink.API.Services;

public interface IUserService
{
    Task<PagedResult<User>> GetUsersAsync(UserQueryParams query);
    Task<User?>             GetByIdAsync(int id);
    Task<bool>              UpdateRoleAsync(int id, string role);
    Task<bool>              DeleteAsync(int id);
}

public class UserQueryParams
{
    public int     Page     { get; set; } = 1;
    public int     PageSize { get; set; } = 20;
    public string? Search   { get; set; }   // fullName or email
    public string? Role     { get; set; }   // Fisherman | Buyer | Admin
    public string  SortBy   { get; set; } = "createdAt";
    public string  SortOrder { get; set; } = "desc";
}
