using System.Text.Json;

namespace FishLink.API.Services;

/// <summary>
/// Real weather service using OpenWeatherMap API.
/// Falls back to time-based simulation if the API key is not configured or the call fails.
///
/// Business purpose: Provides weather context for:
///   - Logistics Agent: route selection (avoid flooded roads during heavy rain)
///   - Fisherman dashboard: fishing safety alerts
///   - Admin: operational decision support
///
/// API: https://api.openweathermap.org/data/2.5/weather?q={city}&appid={key}&units=metric
/// Free plan: 1,000 calls/day, no credit card required.
/// Register at: https://home.openweathermap.org/users/sign_up
/// </summary>
public class WeatherService : IWeatherService
{
    private readonly IHttpClientFactory   _httpFactory;
    private readonly IConfiguration       _config;
    private readonly ILogger<WeatherService> _logger;

    // Simple in-memory cache — avoid hitting the API on every logistics request
    private static readonly Dictionary<string, (WeatherResult result, DateTime expiresAt)> _cache = new();
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(15);

    public WeatherService(
        IHttpClientFactory httpFactory,
        IConfiguration config,
        ILogger<WeatherService> logger)
    {
        _httpFactory = httpFactory;
        _config      = config;
        _logger      = logger;
    }

    public async Task<WeatherResult> GetWeatherAsync(string location)
    {
        var cacheKey = location.ToLower().Trim();

        // Check cache
        if (_cache.TryGetValue(cacheKey, out var cached) && cached.expiresAt > DateTime.UtcNow)
        {
            _logger.LogDebug("Weather cache hit for {Location}", location);
            return cached.result;
        }

        var apiKey = _config["OpenWeatherMap:ApiKey"];
        var baseUrl = _config["OpenWeatherMap:BaseUrl"] ?? "https://api.openweathermap.org/data/2.5";

        // Try real OpenWeatherMap API if key is configured
        if (!string.IsNullOrWhiteSpace(apiKey) &&
            apiKey != "YOUR_OPENWEATHERMAP_API_KEY_HERE")
        {
            try
            {
                var result = await FetchFromOpenWeatherMapAsync(location, apiKey, baseUrl);
                _cache[cacheKey] = (result, DateTime.UtcNow.Add(CacheDuration));
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "OpenWeatherMap API call failed for {Location} — falling back to simulation", location);
            }
        }
        else
        {
            _logger.LogInformation(
                "OpenWeatherMap API key not configured — using simulated weather for {Location}", location);
        }

        // Fallback: time-based simulation (realistic for Sri Lanka climate)
        var simulated = SimulateWeather(location);
        _cache[cacheKey] = (simulated, DateTime.UtcNow.Add(CacheDuration));
        return simulated;
    }

    // ── Real OpenWeatherMap call ───────────────────────────────────────────────

    private async Task<WeatherResult> FetchFromOpenWeatherMapAsync(
        string location, string apiKey, string baseUrl)
    {
        var client = _httpFactory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(8);

        // Map Sri Lanka city names to OWM-compatible names
        var owmCity = MapToOwmCity(location);
        var url = $"{baseUrl}/weather?q={Uri.EscapeDataString(owmCity)},LK&appid={apiKey}&units=metric";

        _logger.LogInformation("Calling OpenWeatherMap for {Location} → {OWMCity}", location, owmCity);

        var response = await client.GetAsync(url);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var weatherArr  = root.GetProperty("weather");
        var first       = weatherArr[0];
        var main        = root.GetProperty("main");
        var wind        = root.GetProperty("wind");

        var condition   = first.GetProperty("main").GetString() ?? "Unknown";
        var description = first.GetProperty("description").GetString() ?? "";
        var icon        = first.GetProperty("icon").GetString() ?? "";
        var temp        = main.GetProperty("temp").GetDouble();
        var humidity    = main.GetProperty("humidity").GetInt32();
        var windMs      = wind.GetProperty("speed").GetDouble();
        var windKmh     = Math.Round(windMs * 3.6, 1);

        var rainExpected  = IsRainy(condition);
        var drivingRisk   = CalcDrivingRisk(condition, windKmh);
        var fishingRisk   = CalcFishingRisk(condition, windKmh);
        var note          = BuildNote(condition, windKmh, rainExpected, drivingRisk);

        return new WeatherResult
        {
            Location     = location,
            Condition    = condition,
            TempCelsius  = Math.Round(temp, 1),
            WindSpeedKmh = windKmh,
            Humidity     = humidity,
            RainExpected = rainExpected,
            DrivingRisk  = drivingRisk,
            FishingRisk  = fishingRisk,
            Note         = note,
            IconCode     = icon,
            Source       = "OpenWeatherMap",
            FetchedAt    = DateTime.UtcNow,
        };
    }

    // ── Simulation fallback ────────────────────────────────────────────────────

    private static WeatherResult SimulateWeather(string location)
    {
        // Sri Lanka: afternoon rain common (14:00–17:00 SL time = 08:30–11:30 UTC)
        var slHour  = DateTime.UtcNow.AddHours(5.5).Hour;
        var isRainy = slHour >= 14 && slHour <= 17;
        var isMonsoon = DateTime.UtcNow.Month is >= 5 and <= 9; // SW monsoon

        var condition    = (isRainy || isMonsoon) ? "Rain" : "Clear";
        var temp         = isRainy ? 27.0 : 32.0;
        var windKmh      = isRainy ? 25.0 : 12.0;
        var humidity     = isRainy ? 85 : 65;
        var drivingRisk  = isRainy ? "Moderate" : "Low";
        var fishingRisk  = (isRainy || windKmh > 30) ? "Moderate" : "Low";

        return new WeatherResult
        {
            Location     = location,
            Condition    = condition,
            TempCelsius  = temp,
            WindSpeedKmh = windKmh,
            Humidity     = humidity,
            RainExpected = isRainy,
            DrivingRisk  = drivingRisk,
            FishingRisk  = fishingRisk,
            Note         = isRainy
                ? "Rain expected. Allow extra travel time and check road conditions."
                : "Good conditions for fishing and logistics operations.",
            Source       = "Simulated (configure OpenWeatherMap:ApiKey for live data)",
            FetchedAt    = DateTime.UtcNow,
        };
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private static string MapToOwmCity(string location) => location.ToLower() switch
    {
        var s when s.Contains("negombo")   => "Negombo",
        var s when s.Contains("colombo")   => "Colombo",
        var s when s.Contains("kandy")     => "Kandy",
        var s when s.Contains("galle")     => "Galle",
        var s when s.Contains("jaffna")    => "Jaffna",
        var s when s.Contains("matara")    => "Matara",
        var s when s.Contains("batticaloa")=> "Batticaloa",
        _                                  => "Negombo",   // default to Negombo (project base)
    };

    private static bool IsRainy(string condition) =>
        condition is "Rain" or "Drizzle" or "Thunderstorm" or "Snow";

    private static string CalcDrivingRisk(string condition, double windKmh) =>
        condition == "Thunderstorm" || windKmh > 50 ? "High"
        : IsRainy(condition) || windKmh > 30        ? "Moderate"
        : "Low";

    private static string CalcFishingRisk(string condition, double windKmh) =>
        condition == "Thunderstorm" || windKmh > 40 ? "High"
        : IsRainy(condition) || windKmh > 25        ? "Moderate"
        : "Low";

    private static string BuildNote(string condition, double windKmh, bool rain, string drivingRisk)
    {
        var parts = new List<string>();
        if (rain)       parts.Add("Rain expected — allow +20 min travel buffer.");
        if (windKmh > 40) parts.Add($"Strong winds ({windKmh} km/h) — avoid open-sea fishing.");
        if (drivingRisk == "High") parts.Add("High driving risk — consider route alternatives.");
        if (!parts.Any()) parts.Add("Good conditions for operations.");
        return string.Join(" ", parts);
    }
}
