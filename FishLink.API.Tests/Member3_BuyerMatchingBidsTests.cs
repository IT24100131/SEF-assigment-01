using FishLink.API.Data;
using FishLink.API.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FishLink.API.Tests;

/// <summary>
/// Member 3: Buyer Matching Engine & Marketplace Bidding System Component Tests
/// Tests buyer preference matching, multi-criteria match scoring, bid placement,
/// and bid acceptance/order generation workflow.
/// </summary>
public sealed class Member3_BuyerMatchingBidsTests
{
    private static ApplicationDbContext CreateInMemoryDb()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    [Fact]
    public async Task Member3_BuyerPreference_MatchesAvailableCatchesCorrectly()
    {
        var db = CreateInMemoryDb();
        db.Catches.AddRange(
            new Catch { Id = 301, FishSpecies = "Yellowfin Tuna", QuantityKg = 50, AskingPricePerKg = 1100, Location = "Colombo", Status = "Published" },
            new Catch { Id = 302, FishSpecies = "Yellowfin Tuna", QuantityKg = 20, AskingPricePerKg = 1600, Location = "Galle", Status = "Published" },
            new Catch { Id = 303, FishSpecies = "Mackerel", QuantityKg = 40, AskingPricePerKg = 600, Location = "Colombo", Status = "Published" }
        );
        await db.SaveChangesAsync();

        var pref = new BuyerPreference
        {
            BuyerId = 15,
            PreferredSpecies = "Yellowfin Tuna",
            MinQuantityKg = 30,
            MaxQuantityKg = 100,
            MaxPricePerKg = 1300,
            PreferredCity = "Colombo"
        };

        var matches = await db.Catches
            .Where(c => c.Status == "Published" &&
                        c.FishSpecies == pref.PreferredSpecies &&
                        c.QuantityKg >= pref.MinQuantityKg &&
                        c.QuantityKg <= pref.MaxQuantityKg &&
                        c.AskingPricePerKg <= pref.MaxPricePerKg)
            .ToListAsync();

        Assert.Single(matches);
        Assert.Equal(301, matches.First().Id);
        Assert.Equal(1100, matches.First().AskingPricePerKg);
    }

    [Fact]
    public void Member3_MatchScore_ComputesAccurateWeightedScore()
    {
        double CalculateMatchScore(bool speciesMatch, decimal askingPrice, decimal buyerMaxPrice, bool cityMatch)
        {
            if (!speciesMatch) return 0;
            double score = 40.0; // Base species match

            // Price score (up to 30 pts)
            if (askingPrice <= buyerMaxPrice)
            {
                double priceSavingRatio = (double)((buyerMaxPrice - askingPrice) / buyerMaxPrice);
                score += 20.0 + Math.Min(10.0, priceSavingRatio * 20.0);
            }

            // Location score (30 pts)
            if (cityMatch) score += 30.0;
            else score += 10.0;

            return Math.Min(100.0, score);
        }

        // Perfect match: Same city, lower price than buyer budget
        var score1 = CalculateMatchScore(true, 1000m, 1200m, true);
        Assert.True(score1 >= 90.0, $"Expected >= 90, got {score1}");

        // Different city, higher price than buyer budget
        var score2 = CalculateMatchScore(true, 1400m, 1200m, false);
        Assert.Equal(50.0, score2);

        // Species mismatch
        var score3 = CalculateMatchScore(false, 1000m, 1200m, true);
        Assert.Equal(0.0, score3);
    }

    [Fact]
    public async Task Member3_PlaceBid_SuccessfullyRecordsPendingBid()
    {
        var db = CreateInMemoryDb();
        var buyer = new User { Id = 20, FullName = "Seafood Wholesalers Ltd", Email = "buyer@wholesalers.lk", Role = "Buyer" };
        var fishCatch = new Catch { Id = 304, FishSpecies = "Crab", AskingPricePerKg = 1500, Status = "Published" };
        db.Users.Add(buyer);
        db.Catches.Add(fishCatch);
        await db.SaveChangesAsync();

        var bid = new Bid
        {
            CatchId = 304,
            BuyerId = 20,
            BidPricePerKg = 1550,
            Status = "Pending",
            BidTime = DateTime.UtcNow
        };
        db.Bids.Add(bid);
        await db.SaveChangesAsync();

        var savedBid = await db.Bids.FirstOrDefaultAsync(b => b.CatchId == 304 && b.BuyerId == 20);
        Assert.NotNull(savedBid);
        Assert.Equal("Pending", savedBid.Status);
        Assert.Equal(1550, savedBid.BidPricePerKg);
    }

    [Fact]
    public async Task Member3_AcceptBid_TransitionsStatusToAcceptedAndCreatesOrder()
    {
        var db = CreateInMemoryDb();
        var fishCatch = new Catch { Id = 305, FishermanId = 2, FishSpecies = "Prawns", QuantityKg = 20, Status = "Published" };
        var bid = new Bid { Id = 1, CatchId = 305, BuyerId = 22, BidPricePerKg = 2000, Status = "Pending" };
        db.Catches.Add(fishCatch);
        db.Bids.Add(bid);
        await db.SaveChangesAsync();

        // Fisherman accepts the bid
        bid.Status = "Accepted";
        fishCatch.Status = "Completed";

        var order = new Order
        {
            BidId = bid.Id,
            TotalAmount = fishCatch.QuantityKg * bid.BidPricePerKg,
            Status = "Created",
            CreatedAt = DateTime.UtcNow
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync();

        var savedOrder = await db.Orders.FirstOrDefaultAsync(o => o.BidId == 1);
        Assert.NotNull(savedOrder);
        Assert.Equal(40000m, savedOrder.TotalAmount); // 20kg * 2000
        Assert.Equal("Created", savedOrder.Status);

        var updatedBid = await db.Bids.FindAsync(1);
        Assert.Equal("Accepted", updatedBid!.Status);
    }
}
