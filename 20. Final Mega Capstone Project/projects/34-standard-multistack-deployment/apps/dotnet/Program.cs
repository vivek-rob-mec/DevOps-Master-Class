var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole();
builder.Services.Configure<HostOptions>(options => options.ShutdownTimeout = TimeSpan.FromSeconds(20));
var app = builder.Build();
app.Run(async context => {
    object body = new { status = "ok" };
    if (context.Request.Method != "GET") {
        context.Response.StatusCode = 405;
        context.Response.Headers.Allow = "GET";
        body = new { error = "method not allowed" };
    } else if (context.Request.Path == "/api/info") {
        body = new { service = "deployment-demo", stack = "dotnet",
            version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "dev",
            environment = Environment.GetEnvironmentVariable("APP_ENV") ?? "local" };
    } else if (context.Request.Path != "/healthz" && context.Request.Path != "/readyz") {
        context.Response.StatusCode = 404;
        body = new { error = "not found" };
    }
    await context.Response.WriteAsJsonAsync(body);
    app.Logger.LogInformation("Request completed with status {Status}", context.Response.StatusCode);
});
app.Run();
