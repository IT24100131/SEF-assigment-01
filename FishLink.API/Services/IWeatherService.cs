namespace FishLink.API.Services;

public interface IWeatherService
{
    /// <summary>
    /// Get current weather for a city/location relevant to fishing operations.
    /// Returns structured weather data for logistics planning and catch safety decisions.
    /// </summary>
    Task<WeatherResult> GetWeatherAsync(string location);
}

public class WeatherResult
{
    public string   Location      { get; set; } = string.Empty;
    public string   Condition     { get; set; } = string.Empty;  // Clear, Rain, Thunderstorm, etc.
    public double   TempCelsius   { get; set; }
    public double   WindSpeedKmh  { get; set; }
    public int      Humidity      { get; set; }
    public bool     RainExpected  { get; set; }
    public string   DrivingRisk   { get; set; } = "Low";         // Low / Moderate / High
    public string   FishingRisk   { get; set; } = "Low";         // Low / Moderate / High
    public string   Note          { get; set; } = string.Empty;
    public string   Source        { get; set; } = string.Empty;  // "OpenWeatherMap" or "Simulated"
    public DateTime FetchedAt     { get; set; } = DateTime.UtcNow;

    // Icon code from OpenWeatherMap (for UI display)
    public string   IconCode      { get; set; } = string.Empty;
    public string   IconUrl       => string.IsNullOrEmpty(IconCode)
        ? string.Empty
        : $"https://openweathermap.org/img/wn/{IconCode}@2x.png";
}
