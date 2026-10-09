using System.Security.Claims;
using FishLink.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FishLink.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly IUserService _service;
    public UsersController(IUserService service) => _service = service;

    // GET /api/Users/me - Current logged-in user profile
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(idClaim) || !int.TryParse(idClaim, out var userId))
            return Unauthorized();

        var u = await _service.GetByIdAsync(userId);
        return u == null ? NotFound("User not found.") : Ok(new
        {
            u.Id,
            u.FullName,
            u.Email,
            u.Role,
            u.CreatedAt
        });
    }

    // PUT /api/Users/profile - Update full name or change password
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest req)
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(idClaim) || !int.TryParse(idClaim, out var userId))
            return Unauthorized();

        await _service.UpdateProfileAsync(userId, req.FullName, req.CurrentPassword, req.NewPassword);
        var updated = await _service.GetByIdAsync(userId);
        return Ok(new
        {
            message = "Profile updated successfully.",
            user = new
            {
                updated!.Id,
                updated.FullName,
                updated.Email,
                updated.Role,
                updated.CreatedAt
            }
        });
    }

    // GET /api/Users?page=1&pageSize=20&search=kaveesha&role=Fisherman&sortBy=name
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetUsers([FromQuery] UserQueryParams query)
        => Ok(await _service.GetUsersAsync(query));

    [HttpGet("{id}")]
    public async Task<IActionResult> GetUser(int id)
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var roleClaim = User.FindFirst(ClaimTypes.Role)?.Value;

        // Non-admin can only view their own user details
        if (roleClaim != "Admin" && (!int.TryParse(idClaim, out var userId) || userId != id))
            return Forbid();

        var u = await _service.GetByIdAsync(id);
        return u == null ? NotFound($"User {id} not found.") : Ok(u);
    }

    [HttpPatch("{id}/role")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateRole(int id, [FromBody] UpdateRoleRequest req)
    {
        await _service.UpdateRoleAsync(id, req.Role);
        return Ok(new { message = $"User {id} role updated to {req.Role}." });
    }

    // DELETE /api/Users/me - Self account deletion
    [HttpDelete("me")]
    public async Task<IActionResult> DeleteMyAccount()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(idClaim) || !int.TryParse(idClaim, out var userId))
            return Unauthorized();

        await _service.DeleteAsync(userId);
        return Ok(new { message = "Account successfully deleted." });
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}

public class UpdateRoleRequest
{
    public string Role { get; set; } = string.Empty;
}

public class UpdateProfileRequest
{
    public string  FullName        { get; set; } = string.Empty;
    public string? CurrentPassword { get; set; }
    public string? NewPassword     { get; set; }
}
