using System.Text;
using FishLink.API;
using FishLink.API.Data;
using FishLink.API.Middleware;

using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Serilog.Events;

AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

// ── Serilog structured logging ────────────────────────────────────────────────
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .MinimumLevel.Override("Microsoft.EntityFrameworkCore.Database.Command", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Application", "FishLink.API")
    .WriteTo.Console(outputTemplate:
        "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext} — {Message:lj}{NewLine}{Exception}")
    .WriteTo.File("logs/fishlink-.log",
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 7,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {SourceContext} {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // Replace default logging with Serilog
    builder.Host.UseSerilog();

    // ── Services ──────────────────────────────────────────────────────────────
    builder.Services.AddControllers(options =>
    {
        var factoriesToRemove = options.ValueProviderFactories
            .Where(f => f.GetType().Name.Contains("Form"))
            .ToList();
        foreach (var factory in factoriesToRemove)
            options.ValueProviderFactories.Remove(factory);
    });

    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(c =>
    {
        c.SwaggerDoc("v1", new() { Title = "FishLink AI API", Version = "v1" });
    });

    // PostgreSQL
    builder.Services.AddDbContext<ApplicationDbContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

    // JWT Authentication
    var jwtSettings = builder.Configuration.GetSection("Jwt");
    var key = Encoding.ASCII.GetBytes(jwtSettings["Key"]!);
    builder.Services.AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = jwtSettings["Issuer"],
            ValidAudience            = jwtSettings["Audience"],
            IssuerSigningKey         = new SymmetricSecurityKey(key),
        };
    });

    // CORS — allow React (3000) and Flutter
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("AllowAll", policy =>
            policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
    });

    // HTTP client for calling AI agent (internal service)
    builder.Services.AddHttpClient("AiAgent", client =>
    {
        client.BaseAddress = new Uri(
            builder.Configuration["AiAgent:BaseUrl"] ?? "http://localhost:8000");
        client.Timeout = TimeSpan.FromSeconds(30);
    });

    // ── Business service layer ────────────────────────────────────────────────
    builder.Services.AddScoped<FishLink.API.Services.ICatchService,   FishLink.API.Services.CatchService>();
    builder.Services.AddScoped<FishLink.API.Services.IUserService,    FishLink.API.Services.UserService>();
    builder.Services.AddScoped<FishLink.API.Services.IWeatherService, FishLink.API.Services.WeatherService>();

    // ── Health check endpoint ─────────────────────────────────────────────────
    builder.Services.AddHealthChecks()
        .AddNpgSql(builder.Configuration.GetConnectionString("DefaultConnection")!);

    var app = builder.Build();

    // ── Seed mode ─────────────────────────────────────────────────────────────
    if (args.Contains("--seed"))
    {
        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await DataSeeder.SeedAsync(db);
        await LogisticsSeeder.SeedAsync(db);
        return;
    }

    // ── Middleware pipeline ───────────────────────────────────────────────────
    // 1. Global error handler — must be FIRST
    app.UseGlobalErrorHandling();

    // 2. Serilog request logging
    app.UseSerilogRequestLogging(opts =>
    {
        opts.MessageTemplate =
            "HTTP {RequestMethod} {RequestPath} responded {StatusCode} in {Elapsed:0.000} ms";
    });

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI(c =>
        {
            c.SwaggerEndpoint("/swagger/v1/swagger.json", "FishLink AI API v1");
            c.RoutePrefix = "swagger";
        });
    }

    app.UseCors("AllowAll");
    if (!app.Environment.IsDevelopment())
    {
        app.UseHttpsRedirection();
    }
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();
    app.MapHealthChecks("/health");
    app.MapGet("/", () => Results.Ok(new
    {
        service = "FishLink API",
        status = "running",
        health = "/health",
        swagger = "/swagger"
    }));

    Log.Information("FishLink API starting on {Environment}", app.Environment.EnvironmentName);
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "FishLink API failed to start");
}
finally
{
    Log.CloseAndFlush();
}
