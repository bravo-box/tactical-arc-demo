using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<MonitorOptions>(
    builder.Configuration.GetSection(MonitorOptions.SectionName));
builder.Services.Configure<ServiceBusOptions>(
    builder.Configuration.GetSection(ServiceBusOptions.SectionName));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<HeartbeatStore>();
builder.Services.AddHostedService<ServiceBusHeartbeatConsumer>();

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));
app.MapGet("/readyz", () => Results.Ok(new { status = "ready" }));
app.MapGet("/api/devices", (HeartbeatStore store) => Results.Ok(store.GetDevices()));
app.MapGet(
    "/api/devices/{deviceName}",
    (string deviceName, HeartbeatStore store) =>
        store.GetDevice(deviceName) is { } device
            ? Results.Ok(device)
            : Results.NotFound(new { error = "device not found" }));

app.MapFallbackToFile("index.html");
app.Run();

public partial class Program;
