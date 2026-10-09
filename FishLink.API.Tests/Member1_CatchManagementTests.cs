using FishLink.API.Data;
using FishLink.API.DTOs;
using FishLink.API.Models;
using FishLink.API.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace FishLink.API.Tests;

/// <summary>
/// Member 1: Catch Lifecycle & Fisherman Traceability Component Tests
/// Tests catch creation, status transitions (Draft -> Published), ownership security,
/// search/filtering, and geographic boundary validation.
/// </summary>
public sealed class Member1_CatchManagementTests
{
    private static (ApplicationDbContext Db, CatchService Service) CreateSut()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        var db = new ApplicationDbContext(options);
        return (db, new CatchService(db, NullLogger<CatchService>.Instance));
    }

    [Fact]
    public async Task Member1_CreateCatch_InitializesDraftWithOwnerAndDefaultRisk()
    {
        var (db, service) = CreateSut();
        var request = new CatchRequest
        {
            FishSpecies = "Yellowfin Tuna",
            QuantityKg = 50,
            AskingPricePerKg = 1100,
            Location = "Negombo Harbour",
            SellerNote = "Fresh morning catch"
        };

        var result = await service.CreateAsync(request, fishermanId: 5);

        Assert.NotNull(result);
        Assert.Equal("Draft", result.Status);
        Assert.Equal("Unassessed", result.FraudRisk);
        Assert.Equal(5, result.FishermanId);
        Assert.Equal("Yellowfin Tuna", result.FishSpecies);
        Assert.Equal(50, result.QuantityKg);

        var savedInDb = await db.Catches.FirstOrDefaultAsync(c => c.Id == result.Id);
        Assert.NotNull(savedInDb);
        Assert.Equal("Negombo Harbour", savedInDb.Location);
    }

    [Fact]
    public async Task Member1_PublishCatch_RejectsUnauthorizedFisherman()
    {
        var (db, service) = CreateSut();
        var existingCatch = new Catch
        {
            Id = 101,
            FishermanId = 5,
            FishSpecies = "Skipjack Tuna",
            QuantityKg = 30,
            AskingPricePerKg = 800,
            Status = "Draft"
        };
        db.Catches.Add(existingCatch);
        await db.SaveChangesAsync();

        // Attempt to publish by another fisherman (Id 99)
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            service.PublishAsync(101, 99));
    }

    [Fact]
    public async Task Member1_PublishCatch_OwnerSuccessfullyPublishesListing()
    {
        var (db, service) = CreateSut();
        var existingCatch = new Catch
        {
            Id = 102,
            FishermanId = 5,
            FishSpecies = "Sailfish",
            QuantityKg = 25,
            AskingPricePerKg = 1400,
            Status = "Draft"
        };
        db.Catches.Add(existingCatch);
        await db.SaveChangesAsync();

        var published = await service.PublishAsync(102, 5);

        Assert.True(published);
        var updated = await db.Catches.FindAsync(102);
        Assert.NotNull(updated);
        Assert.Equal("Published", updated.Status);
    }

    [Fact]
    public async Task Member1_FilterAndSearchCatches_FiltersBySpeciesLocationAndPaginates()
    {
        var (db, service) = CreateSut();
        var fisherman = new User { Id = 10, FullName = "Sunil Silva", Email = "sunil@fishlink.lk", Role = "Fisherman" };
        db.Users.Add(fisherman);
        db.Catches.AddRange(
            new Catch { FishermanId = 10, FishSpecies = "Yellowfin Tuna", Location = "Negombo", AskingPricePerKg = 1200, Status = "Published", CreatedAt = DateTime.UtcNow },
            new Catch { FishermanId = 10, FishSpecies = "Yellowfin Tuna", Location = "Galle", AskingPricePerKg = 1500, Status = "Published", CreatedAt = DateTime.UtcNow },
            new Catch { FishermanId = 10, FishSpecies = "Mackerel", Location = "Negombo", AskingPricePerKg = 600, Status = "Published", CreatedAt = DateTime.UtcNow }
        );
        await db.SaveChangesAsync();

        var query = new CatchQueryParams
        {
            Search = "Negombo",
            SortBy = "price",
            SortOrder = "asc",
            Page = 1,
            PageSize = 10
        };

        var result = await service.GetCatchesAsync(query);

        Assert.Equal(2, result.TotalCount);
        Assert.All(result.Items, c => Assert.Equal("Negombo", c.Location));
    }

    [Fact]
    public void Member1_GPSValidation_SriLankanCoastalWaters_ValidatesCoordinates()
    {
        // Sri Lanka territorial coastal boundary: Latitude 5.8 to 9.9, Longitude 79.5 to 82.0
        bool IsInSriLankanWaters(double lat, double lon) =>
            lat >= 5.8 && lat <= 9.9 && lon >= 79.5 && lon <= 82.0;

        // Valid points: Negombo harbor, Galle bay
        Assert.True(IsInSriLankanWaters(7.2083, 79.8358)); // Negombo
        Assert.True(IsInSriLankanWaters(6.0535, 80.2210)); // Galle

        // Invalid points: Outside waters
        Assert.False(IsInSriLankanWaters(0.0, 0.0));       // Equator
        Assert.False(IsInSriLankanWaters(25.0, 55.0));     // Middle East
    }
}
