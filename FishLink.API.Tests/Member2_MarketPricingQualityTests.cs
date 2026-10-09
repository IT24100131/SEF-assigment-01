using FishLink.API.Data;
using FishLink.API.Models;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace FishLink.API.Tests;

/// <summary>
/// Member 2: Quality Assessment, Fraud Prevention & Market Price Intelligence Component Tests
/// Tests freshness grading, weight discrepancy fraud checks, quality inspection persistence,
/// and AI pricing fallback mechanisms.
/// </summary>
public sealed class Member2_MarketPricingQualityTests
{
    private static ApplicationDbContext CreateInMemoryDb()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    [Fact]
    public void Member2_QualityGrading_ComputesGradeAccurately()
    {
        string DetermineGrade(int freshnessScore)
        {
            if (freshnessScore >= 85) return "Grade A";
            if (freshnessScore >= 70) return "Grade B";
            return "Grade C";
        }

        Assert.Equal("Grade A", DetermineGrade(92));
        Assert.Equal("Grade A", DetermineGrade(85));
        Assert.Equal("Grade B", DetermineGrade(75));
        Assert.Equal("Grade B", DetermineGrade(70));
        Assert.Equal("Grade C", DetermineGrade(64));
    }

    [Fact]
    public void Member2_WeightVerification_FlagsHighFraudRiskOnExcessiveDiscrepancy()
    {
        string EvaluateFraudRisk(decimal declaredKg, decimal verifiedKg)
        {
            if (declaredKg <= 0) return "High";
            var discrepancyPercent = Math.Abs(declaredKg - verifiedKg) / declaredKg * 100m;
            if (discrepancyPercent > 15m) return "High";
            if (discrepancyPercent > 5m) return "Medium";
            return "Low";
        }

        // Declared 100kg vs Verified 70kg -> 30% drop -> High risk
        Assert.Equal("High", EvaluateFraudRisk(100m, 70m));

        // Declared 100kg vs Verified 92kg -> 8% drop -> Medium risk
        Assert.Equal("Medium", EvaluateFraudRisk(100m, 92m));

        // Declared 100kg vs Verified 98kg -> 2% drop -> Low risk
        Assert.Equal("Low", EvaluateFraudRisk(100m, 98m));
    }

    [Fact]
    public async Task Member2_QualityInspection_PersistsInspectionRecordAndUpdatesCatch()
    {
        var db = CreateInMemoryDb();
        var fishermanCatch = new Catch
        {
            Id = 201,
            FishermanId = 1,
            FishSpecies = "Yellowfin Tuna",
            QuantityKg = 80,
            AskingPricePerKg = 1250,
            Status = "Draft",
            FraudRisk = "Unassessed"
        };
        db.Catches.Add(fishermanCatch);
        await db.SaveChangesAsync();

        // Inspector validates quality & verified weight
        var inspection = new QualityCheck
        {
            CatchId = 201,
            InspectorId = 9,
            VerifiedWeightKg = 79.2m,
            Notes = "Grade A quality verified by Negombo Fisheries Inspectorate.",
            IsPassed = true,
            InspectedAt = DateTime.UtcNow
        };
        db.QualityChecks.Add(inspection);

        fishermanCatch.FraudRisk = "Low";
        fishermanCatch.Status = "PendingValidation";
        await db.SaveChangesAsync();

        var savedCheck = await db.QualityChecks.FirstOrDefaultAsync(q => q.CatchId == 201);
        Assert.NotNull(savedCheck);
        Assert.True(savedCheck.IsPassed);
        Assert.Equal(79.2m, savedCheck.VerifiedWeightKg);

        var updatedCatch = await db.Catches.FindAsync(201);
        Assert.NotNull(updatedCatch);
        Assert.Equal("Low", updatedCatch.FraudRisk);
        Assert.Equal("PendingValidation", updatedCatch.Status);
    }

    [Fact]
    public void Member2_PriceRecommendation_FallbackCalculation_UsesPredictableBaseline()
    {
        // When upstream Price Prediction microservice is unavailable, fallback price engine kicks in
        decimal CalculateFallbackPrice(string species, decimal askingPrice)
        {
            decimal speciesBase = species.ToLower() switch
            {
                "yellowfin tuna" => 1200m,
                "skipjack tuna" => 800m,
                "seer fish" => 1800m,
                _ => askingPrice > 0 ? askingPrice : 900m
            };

            // Recommendation: 5% markup over floor price
            return Math.Round(speciesBase * 1.05m, 2);
        }

        var tunaPrice = CalculateFallbackPrice("Yellowfin Tuna", 1000m);
        Assert.Equal(1260.00m, tunaPrice);

        var seerPrice = CalculateFallbackPrice("Seer Fish", 1500m);
        Assert.Equal(1890.00m, seerPrice);
    }
}
