using System.Net;
using System.Text.Json;

namespace FishLink.API.Middleware;

/// <summary>
/// Global exception handling middleware.
/// Catches all unhandled exceptions and returns a consistent JSON error response.
/// Logs structured error details using ILogger.
/// </summary>
public class ErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ErrorHandlingMiddleware> _logger;

    public ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
    {
        _next   = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Unhandled exception on {Method} {Path} — {Message}",
                context.Request.Method,
                context.Request.Path,
                ex.Message);

            await WriteErrorResponseAsync(context, ex);
        }
    }

    private static async Task WriteErrorResponseAsync(HttpContext context, Exception ex)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, title) = ex switch
        {
            ArgumentNullException      => (HttpStatusCode.BadRequest,           "Invalid argument"),
            ArgumentException          => (HttpStatusCode.BadRequest,           "Bad request"),
            KeyNotFoundException       => (HttpStatusCode.NotFound,             "Resource not found"),
            UnauthorizedAccessException => (HttpStatusCode.Unauthorized,        "Unauthorized"),
            InvalidOperationException  => (HttpStatusCode.UnprocessableEntity,  "Invalid operation"),
            _                          => (HttpStatusCode.InternalServerError,  "An unexpected error occurred"),
        };

        context.Response.StatusCode = (int)statusCode;

        var body = JsonSerializer.Serialize(new
        {
            status    = (int)statusCode,
            title,
            detail    = ex.Message,
            timestamp = DateTime.UtcNow,
            traceId   = context.TraceIdentifier,
        }, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

        await context.Response.WriteAsync(body);
    }
}

// Extension method for clean registration in Program.cs
public static class ErrorHandlingMiddlewareExtensions
{
    public static IApplicationBuilder UseGlobalErrorHandling(this IApplicationBuilder app)
        => app.UseMiddleware<ErrorHandlingMiddleware>();
}
