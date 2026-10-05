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
    public async Task ReceiveValidationResultAsync_updates_a_published_catch_status()
    {
        var (db, service) = CreateSut();
        db.Catches.Add(new Catch { Id = 1, FishermanId = 7, FishSpecies = "Tuna", Status = "Published" });
        await db.SaveChangesAsync();

        await service.ReceiveValidationResultAsync(new ValidationResultRequest
        {
            CatchId = 1,
            FraudRisk = "High",
            RecommendedStatus = "Draft",
            RequiresAdminReview = true,
        });

        var result = await db.Catches.FindAsync(1);
        Assert.Equal("Draft", result!.Status);
        Assert.Equal("High", result.FraudRisk);
        Assert.True(result.RequiresAdminReview);
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

    [Fact]
    public async Task UpdateAsync_clears_stale_validation_and_returns_published_catch_to_draft()
    {
        var (db, service) = CreateSut();
        db.Catches.Add(new Catch
        {
            Id = 1,
            FishermanId = 7,
            FishSpecies = "Mackerel",
            QuantityKg = 160,
            AskingPricePerKg = 1700,
            VerifiedWeightKg = 162,
            Status = "Published",
            FraudRisk = "High",
            WeightDiscrepancyPct = 1.2m,
            QualityScore = 95,
            ValidationSummary = "Old validation result",
            RequiresAdminReview = true,
        });
        await db.SaveChangesAsync();

        await service.UpdateAsync(1, new CatchRequest
        {
            FishSpecies = "Mackerel",
            QuantityKg = 160,
            AskingPricePerKg = 683,
            Location = "Negombo",
            VerifiedWeightKg = 160,
        }, 7);

        var result = await db.Catches.FindAsync(1);
        Assert.Equal("Draft", result!.Status);
        Assert.Equal("Unassessed", result.FraudRisk);
        Assert.Equal(0, result.WeightDiscrepancyPct);
        Assert.Equal(0, result.QualityScore);
        Assert.Empty(result.ValidationSummary);
        Assert.False(result.RequiresAdminReview);
    }
}
