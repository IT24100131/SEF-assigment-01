using FishLink.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FishLink.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class UsersController : ControllerBase
{
    private readonly IUserService _service;
    public UsersController(IUserService service) => _service = service;

    // GET /api/Users?page=1&pageSize=20&search=kaveesha&role=Fisherman&sortBy=name
    [HttpGet]
    public async Task<IActionResult> GetUsers([FromQuery] UserQueryParams query)
        => Ok(await _service.GetUsersAsync(query));

    [HttpGet("{id}")]
    public async Task<IActionResult> GetUser(int id)
    {
        var u = await _service.GetByIdAsync(id);
        return u == null ? NotFound($"User {id} not found.") : Ok(u);
    }

    [HttpPatch("{id}/role")]
    public async Task<IActionResult> UpdateRole(int id, [FromBody] UpdateRoleRequest req)
    {
        await _service.UpdateRoleAsync(id, req.Role);
        return Ok(new { message = $"User {id} role updated to {req.Role}." });
    }

    [HttpDelete("{id}")]
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
