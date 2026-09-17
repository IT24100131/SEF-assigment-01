using FishLink.API.Data;
using FishLink.API.DTOs;
using FishLink.API.Models;
using FishLink.API.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace FishLink.API.Tests;

public sealed class CatchServiceTests
{
    private static (ApplicationDbContext Db, CatchService Service) CreateSut()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        var db = new ApplicationDbContext(options);
        return (db, new CatchService(db, NullLogger<CatchService>.Instance));
    }

    [Fact]
    public async Task CreateAsync_creates_draft_owned_by_fisherman()
    {
        var (db, service) = CreateSut();
        var result = await service.CreateAsync(new CatchRequest
        {
            FishSpecies = "Tuna", QuantityKg = 40, AskingPricePerKg = 1200,
            Location = "Negombo"
        }, 7);

        Assert.Equal("Draft", result.Status);
        Assert.Equal("Unassessed", result.FraudRisk);
        Assert.Equal(7, result.FishermanId);
        Assert.Single(await db.Catches.ToListAsync());
    }

    [Fact]
    public async Task PublishAsync_rejects_a_listing_owned_by_another_user()
    {
        var (db, service) = CreateSut();
        db.Catches.Add(new Catch { Id = 1, FishermanId = 7, FishSpecies = "Tuna", Status = "Draft" });
        await db.SaveChangesAsync();

        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => service.PublishAsync(1, 9));
    }

    [Fact]
    public async Task GetCatchesAsync_filters_sorts_and_paginates()
    {
        var (db, service) = CreateSut();
        db.Users.Add(new User { Id = 1, FullName = "Test Fisherman", Email = "test@example.com", Role = "Fisherman" });
        db.Catches.AddRange(
            new Catch { FishermanId = 1, FishSpecies = "Tuna", Location = "Galle", AskingPricePerKg = 900, CreatedAt = DateTime.UtcNow },
            new Catch { FishermanId = 1, FishSpecies = "Tuna", Location = "Negombo", AskingPricePerKg = 1300, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();

        var result = await service.GetCatchesAsync(new CatchQueryParams
        { Search = "negombo", SortBy = "price", SortOrder = "desc", PageSize = 1 });

        Assert.Equal(1, result.TotalCount);
        Assert.Equal("Negombo", result.Items.Single().Location);
    }
}
