using FishLink.API.Data;
using FishLink.API.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace FishLink.API.Controllers;

// ── DTOs ─────────────────────────────────────────────────────────────────────

public class BuyerPreferenceRequest
{
    public string  PreferredSpecies { get; set; } = string.Empty;
    public decimal MinQuantityKg    { get; set; } = 0;
    public decimal MaxQuantityKg    { get; set; } = 99999;
    public decimal MaxPricePerKg    { get; set; } = 99999;
    public string  PreferredCity    { get; set; } = string.Empty;
    public string  Notes            { get; set; } = string.Empty;
}

public class MatchedCatch
{
    public int     Id               { get; set; }
    public string  FishSpecies      { get; set; } = string.Empty;
    public decimal QuantityKg       { get; set; }
    public decimal AskingPricePerKg { get; set; }
    public string  Location         { get; set; } = string.Empty;
    public string  Status           { get; set; } = string.Empty;
    public int     QualityScore     { get; set; }
    public string  PhotoUrl         { get; set; } = string.Empty;
    public string  FishermanName    { get; set; } = string.Empty;
    public DateTime CreatedAt       { get; set; }
    public int     MatchScore       { get; set; }
    public string  QualityGrade     { get; set; } = string.Empty;
    public string  MatchReasons     { get; set; } = string.Empty;
}

// ── Controller ────────────────────────────────────────────────────────────────

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BuyerMatchController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public BuyerMatchController(ApplicationDbContext context)
    {
        _context = context;
    }

    // ── Buyer Preference CRUD ─────────────────────────────────────────────────

    /// GET /api/BuyerMatch/preferences/me
    /// Returns current buyer's saved preference.
    [HttpGet("preferences/me")]
    [Authorize(Roles = "Buyer")]
    public async Task<IActionResult> GetMyPreference()
    {
        var buyerId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        var pref = await _context.BuyerPreferences.FirstOrDefaultAsync(p => p.BuyerId == buyerId);
        if (pref == null) return NotFound("No preference saved yet.");
        return Ok(pref);
    }

    /// POST /api/BuyerMatch/preferences/me
    /// Create or update current buyer's preference.
    [HttpPost("preferences/me")]
    [Authorize(Roles = "Buyer")]
    public async Task<IActionResult> SaveMyPreference([FromBody] BuyerPreferenceRequest req)
    {
        var buyerId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        var pref = await _context.BuyerPreferences.FirstOrDefaultAsync(p => p.BuyerId == buyerId);

        if (pref == null)
        {
            pref = new BuyerPreference { BuyerId = buyerId };
            _context.BuyerPreferences.Add(pref);
        }

        pref.PreferredSpecies = req.PreferredSpecies;
        pref.MinQuantityKg    = req.MinQuantityKg;
        pref.MaxQuantityKg    = req.MaxQuantityKg;
        pref.MaxPricePerKg    = req.MaxPricePerKg;
        pref.PreferredCity    = req.PreferredCity;
        pref.Notes            = req.Notes;
        pref.UpdatedAt        = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return Ok(pref);
    }

    // ── Buyer list / profile ──────────────────────────────────────────────────

    /// GET /api/BuyerMatch/buyers
    /// All registered buyers with preference + bid summary (for fisherman).
    [HttpGet("buyers")]
    public async Task<IActionResult> GetBuyers()
    {
        var buyers = await _context.Users
            .Where(u => u.Role == "Buyer")
            .Select(u => new {
                u.Id,
                u.FullName,
                u.Email,
                u.CreatedAt,
                TotalBids    = _context.Bids.Count(b => b.BuyerId == u.Id),
                AcceptedBids = _context.Bids.Count(b => b.BuyerId == u.Id && b.Status == "Accepted"),
                HasPreference = _context.BuyerPreferences.Any(p => p.BuyerId == u.Id),
            })
            .ToListAsync();
        return Ok(buyers);
    }

    /// GET /api/BuyerMatch/buyers/{id}
    /// Single buyer profile + bid history + preference.
    [HttpGet("buyers/{id}")]
    public async Task<IActionResult> GetBuyerProfile(int id)
    {
        var buyer = await _context.Users.FindAsync(id);
        if (buyer == null || buyer.Role != "Buyer") return NotFound("Buyer not found.");

        var pref = await _context.BuyerPreferences.FirstOrDefaultAsync(p => p.BuyerId == id);

        var bids = await _context.Bids
            .Include(b => b.Catch)
            .Where(b => b.BuyerId == id)
            .OrderByDescending(b => b.BidTime)
            .Select(b => new {
                b.Id,
                b.BidPricePerKg,
                b.BidTime,
                b.Status,
                Species  = b.Catch != null ? b.Catch.FishSpecies : "Unknown",
                Quantity = b.Catch != null ? b.Catch.QuantityKg   : 0,
                Location = b.Catch != null ? b.Catch.Location      : "",
            })
            .ToListAsync();

        return Ok(new {
            id           = buyer.Id,
            fullName     = buyer.FullName,
            email        = buyer.Email,
            joinedAt     = buyer.CreatedAt,
            totalBids    = bids.Count,
            acceptedBids = bids.Count(b => b.Status == "Accepted"),
            pendingBids  = bids.Count(b => b.Status == "Pending"),
            bidHistory   = bids,
            preference   = pref == null ? null : new {
                pref.PreferredSpecies,
                pref.MinQuantityKg,
                pref.MaxQuantityKg,
                pref.MaxPricePerKg,
                pref.PreferredCity,
                pref.Notes,
                pref.UpdatedAt,
            },
        });
    }

    // ── Available catches for buyers ──────────────────────────────────────────

    /// GET /api/BuyerMatch/available
    [HttpGet("available")]
    public async Task<IActionResult> GetAvailableCatches()
    {
        var available = await _context.Catches
            .Include(c => c.Fisherman)
            .Where(c => c.Status == "Published" || c.Status == "Bidding")
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        var result = available.Select(c => new MatchedCatch
        {
            Id               = c.Id,
            FishSpecies      = c.FishSpecies,
            QuantityKg       = c.QuantityKg,
            AskingPricePerKg = c.AskingPricePerKg,
            Location         = c.Location,
            Status           = c.Status,
            QualityScore     = c.QualityScore,
            PhotoUrl         = c.PhotoUrl,
            FishermanName    = c.Fisherman?.FullName ?? "Unknown",
            CreatedAt        = c.CreatedAt,
            MatchScore       = 0,
            QualityGrade     = ScoreToGrade(c.QualityScore),
            MatchReasons     = string.Empty,
        });

        return Ok(result);
    }

    // ── Recommendation endpoint ───────────────────────────────────────────────

    /// POST /api/BuyerMatch/recommend
    /// Score available catches against buyer preferences + bid history.
    /// If called by authenticated Buyer → auto-loads their saved preference.
    /// Also accepts an explicit preference in request body (for manual search).
    [HttpPost("recommend")]
    public async Task<IActionResult> GetRecommendations([FromBody] BuyerPreferenceRequest? req = null)
    {
        BuyerPreference? savedPref = null;

        // Try to load saved preference for current buyer
        var buyerIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (buyerIdClaim != null)
        {
            int buyerId = int.Parse(buyerIdClaim);
            savedPref = await _context.BuyerPreferences
                .FirstOrDefaultAsync(p => p.BuyerId == buyerId);

            // Build request from saved pref if no explicit one provided
            if (req == null && savedPref != null)
            {
                req = new BuyerPreferenceRequest
                {
                    PreferredSpecies = savedPref.PreferredSpecies,
                    MinQuantityKg    = savedPref.MinQuantityKg,
                    MaxQuantityKg    = savedPref.MaxQuantityKg,
                    MaxPricePerKg    = savedPref.MaxPricePerKg,
                    PreferredCity    = savedPref.PreferredCity,
                    Notes            = savedPref.Notes,
                };
            }
        }

        req ??= new BuyerPreferenceRequest(); // blank pref → show all catches scored by quality/freshness

        var catches = await _context.Catches
            .Include(c => c.Fisherman)
            .Where(c => c.Status == "Published" || c.Status == "Bidding")
            .ToListAsync();

        // Load bid history for this buyer (if authenticated)
        var bidHistory = new List<Bid>();
        if (buyerIdClaim != null)
        {
            int buyerId = int.Parse(buyerIdClaim);
            bidHistory = await _context.Bids
                .Include(b => b.Catch)
                .Where(b => b.BuyerId == buyerId)
                .ToListAsync();
        }

        var scored = catches
            .Select(c => ScoreMatch(c, req, bidHistory))
            .Where(m => m.MatchScore >= 20)
            .OrderByDescending(m => m.MatchScore)
            .Take(10)
            .ToList();

        return Ok(new {
            preferences    = req,
            hasSavedPref   = savedPref != null,
            totalAvailable = catches.Count,
            recommendations = scored,
        });
    }

    // ── Scoring algorithm ─────────────────────────────────────────────────────

    private static MatchedCatch ScoreMatch(Catch c, BuyerPreferenceRequest pref, List<Bid> bidHistory)
    {
        int score = 0;
        var reasons = new List<string>();

        // ── 1. Species match (40 pts) ─────────────────────────────────────────
        bool hasSpeciesPref = !string.IsNullOrWhiteSpace(pref.PreferredSpecies);
        if (!hasSpeciesPref)
        {
            score += 20;
            reasons.Add("~ No species preference set");
        }
        else if (c.FishSpecies.Equals(pref.PreferredSpecies, StringComparison.OrdinalIgnoreCase))
        {
            score += 40;
            reasons.Add("✓ Exact species match");
        }
        else
        {
            reasons.Add($"✗ Species {c.FishSpecies} (wanted {pref.PreferredSpecies})");
        }

        // ── 2. Quantity (25 pts) ──────────────────────────────────────────────
        bool hasQtyPref = pref.MaxQuantityKg < 99999 || pref.MinQuantityKg > 0;
        if (!hasQtyPref)
        {
            score += 12;
            reasons.Add("~ No quantity preference");
        }
        else if (c.QuantityKg >= pref.MinQuantityKg && c.QuantityKg <= pref.MaxQuantityKg)
        {
            score += 25;
            reasons.Add($"✓ {c.QuantityKg}kg fits range ({pref.MinQuantityKg}–{pref.MaxQuantityKg}kg)");
        }
        else if (c.QuantityKg > pref.MaxQuantityKg)
        {
            score += 10;
            reasons.Add($"~ {c.QuantityKg}kg over max — partial purchase possible");
        }
        else
        {
            score += 4;
            reasons.Add($"✗ Only {c.QuantityKg}kg (min {pref.MinQuantityKg}kg needed)");
        }

        // ── 3. Price (20 pts) ─────────────────────────────────────────────────
        bool hasPricePref = pref.MaxPricePerKg < 99999;
        if (!hasPricePref)
        {
            score += 10;
            reasons.Add("~ No price preference");
        }
        else if (c.AskingPricePerKg <= pref.MaxPricePerKg)
        {
            decimal pct = (pref.MaxPricePerKg - c.AskingPricePerKg) / pref.MaxPricePerKg * 100;
            int pts = pct >= 20 ? 20 : pct >= 10 ? 15 : 10;
            score += pts;
            decimal saved = pref.MaxPricePerKg - c.AskingPricePerKg;
            reasons.Add($"✓ Rs.{c.AskingPricePerKg}/kg — Rs.{saved:0} below budget");
        }
        else
        {
            reasons.Add($"✗ Rs.{c.AskingPricePerKg}/kg over budget (Rs.{pref.MaxPricePerKg}/kg)");
        }

        // ── 4. Location (10 pts) ──────────────────────────────────────────────
        bool hasCityPref = !string.IsNullOrWhiteSpace(pref.PreferredCity);
        if (!hasCityPref)
        {
            score += 5;
            reasons.Add($"~ No location preference (catch at {c.Location})");
        }
        else if (c.Location.Contains(pref.PreferredCity, StringComparison.OrdinalIgnoreCase))
        {
            score += 10;
            reasons.Add($"✓ Located in {pref.PreferredCity}");
        }
        else
        {
            reasons.Add($"~ Location: {c.Location}");
        }

        // ── 5. Bid history bonus (10 pts) ─────────────────────────────────────
        // Has this buyer bid on same species before? → reliable interest signal
        var speciesBids = bidHistory
            .Where(b => b.Catch?.FishSpecies.Equals(c.FishSpecies, StringComparison.OrdinalIgnoreCase) == true)
            .ToList();

        if (speciesBids.Count >= 3)
        {
            score += 10;
            reasons.Add($"✓ Bid on {c.FishSpecies} {speciesBids.Count}x before — strong interest");
        }
        else if (speciesBids.Count >= 1)
        {
            score += 5;
            reasons.Add($"✓ Previously bid on {c.FishSpecies} ({speciesBids.Count}x)");
        }

        // ── 6. Quality bonus (5 pts) ──────────────────────────────────────────
        if      (c.QualityScore >= 90) { score += 5; reasons.Add("✓ Premium quality (A+)"); }
        else if (c.QualityScore >= 70) { score += 3; reasons.Add("✓ Good quality (A)"); }
        else if (c.QualityScore > 0)   { score += 1; reasons.Add("~ Average quality (B)"); }

        // ── 7. Freshness (5 pts) ──────────────────────────────────────────────
        int daysOld = (int)(DateTime.UtcNow - c.CreatedAt).TotalDays;
        if      (daysOld <= 1) { score += 5; reasons.Add("✓ Listed today"); }
        else if (daysOld <= 3) { score += 3; reasons.Add("✓ Listed this week"); }

        score = Math.Min(score, 100);

        return new MatchedCatch
        {
            Id               = c.Id,
            FishSpecies      = c.FishSpecies,
            QuantityKg       = c.QuantityKg,
            AskingPricePerKg = c.AskingPricePerKg,
            Location         = c.Location,
            Status           = c.Status,
            QualityScore     = c.QualityScore,
            PhotoUrl         = c.PhotoUrl,
            FishermanName    = c.Fisherman?.FullName ?? "Unknown",
            CreatedAt        = c.CreatedAt,
            MatchScore       = score,
            QualityGrade     = ScoreToGrade(c.QualityScore),
            MatchReasons     = string.Join(" · ", reasons),
        };
    }

    // ── Fisherman-side: score buyers against a catch ──────────────────────────

    /// GET /api/BuyerMatch/score-buyers/{catchId}
    /// For a given catch, scores all registered buyers using their saved preferences + bid history.
    [HttpGet("score-buyers/{catchId}")]
    public async Task<IActionResult> ScoreBuyersForCatch(int catchId)
    {
        var fishCatch = await _context.Catches.FindAsync(catchId);
        if (fishCatch == null) return NotFound("Catch not found.");

        var buyers = await _context.Users
            .Where(u => u.Role == "Buyer")
            .ToListAsync();

        var allPrefs = await _context.BuyerPreferences.ToListAsync();
        var allBids  = await _context.Bids.Include(b => b.Catch).ToListAsync();

        var scored = buyers.Select(buyer =>
        {
            var pref     = allPrefs.FirstOrDefault(p => p.BuyerId == buyer.Id);
            var buyerBids = allBids.Where(b => b.BuyerId == buyer.Id).ToList();

            int score = 0;
            var reasons = new List<string>();

            // Preference-based scoring
            if (pref != null)
            {
                // Species
                if (!string.IsNullOrWhiteSpace(pref.PreferredSpecies))
                {
                    if (pref.PreferredSpecies.Equals(fishCatch.FishSpecies, StringComparison.OrdinalIgnoreCase))
                    { score += 40; reasons.Add("✓ Prefers " + fishCatch.FishSpecies); }
                    else
                    { reasons.Add("✗ Prefers " + pref.PreferredSpecies); }
                }
                else { score += 20; reasons.Add("~ No species preference"); }

                // Quantity
                if (fishCatch.QuantityKg >= pref.MinQuantityKg && fishCatch.QuantityKg <= pref.MaxQuantityKg)
                { score += 25; reasons.Add($"✓ Quantity {fishCatch.QuantityKg}kg fits range"); }
                else if (fishCatch.QuantityKg > pref.MaxQuantityKg)
                { score += 10; reasons.Add($"~ Over their max qty ({pref.MaxQuantityKg}kg)"); }
                else
                { score += 4; reasons.Add($"~ Under their min qty ({pref.MinQuantityKg}kg)"); }

                // Price
                if (fishCatch.AskingPricePerKg <= pref.MaxPricePerKg)
                { score += 20; reasons.Add($"✓ Price within their budget (Rs.{pref.MaxPricePerKg}/kg max)"); }
                else
                { reasons.Add($"✗ Price Rs.{fishCatch.AskingPricePerKg} over their budget"); }

                // Location
                if (!string.IsNullOrWhiteSpace(pref.PreferredCity) &&
                    fishCatch.Location.Contains(pref.PreferredCity, StringComparison.OrdinalIgnoreCase))
                { score += 10; reasons.Add($"✓ In their preferred city ({pref.PreferredCity})"); }
                else if (!string.IsNullOrWhiteSpace(pref.PreferredCity))
                { reasons.Add($"~ Their city: {pref.PreferredCity}"); }
                else
                { score += 5; reasons.Add("~ No city preference"); }
            }
            else
            {
                score += 30; // base score for buyers with no preference (open to anything)
                reasons.Add("~ No preference saved — open buyer");
            }

            // Bid history bonus
            var speciesBids = buyerBids
                .Where(b => b.Catch?.FishSpecies.Equals(fishCatch.FishSpecies, StringComparison.OrdinalIgnoreCase) == true)
                .ToList();
            if      (speciesBids.Count >= 3) { score += 10; reasons.Add($"✓ Bid on {fishCatch.FishSpecies} {speciesBids.Count}x"); }
            else if (speciesBids.Count >= 1) { score += 5;  reasons.Add($"✓ Bid on {fishCatch.FishSpecies} before"); }

            score = Math.Min(score, 100);

            return new {
                id           = buyer.Id,
                name         = buyer.FullName,
                email        = buyer.Email,
                matchScore   = score,
                matchReasons = string.Join(" · ", reasons),
                hasPreference = pref != null,
                totalBids    = buyerBids.Count,
                preferredSpecies = pref?.PreferredSpecies ?? "",
                maxBudget    = pref?.MaxPricePerKg ?? 0,
                preferredCity = pref?.PreferredCity ?? "",
            };
        })
        .Where(b => b.matchScore >= 20)
        .OrderByDescending(b => b.matchScore)
        .ToList();

        return Ok(new { catchId, totalBuyers = buyers.Count, scoredBuyers = scored });
    }

    private static string ScoreToGrade(int score) => score switch
    {
        >= 90 => "A+", >= 75 => "A", >= 60 => "B", >= 40 => "C", _ => "Unverified",
    };
}
