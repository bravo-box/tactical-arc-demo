using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<MonitorOptions>(
    builder.Configuration.GetSection(MonitorOptions.SectionName));
builder.Services.Configure<ServiceBusOptions>(
    builder.Configuration.GetSection(ServiceBusOptions.SectionName));
builder.Services.Configure<ImageServiceBusOptions>(
    builder.Configuration.GetSection(ImageServiceBusOptions.SectionName));
builder.Services.Configure<StorageOptions>(
    builder.Configuration.GetSection(StorageOptions.SectionName));
builder.Services.Configure<ImageFeatureOptions>(
    builder.Configuration.GetSection(ImageFeatureOptions.SectionName));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<HeartbeatStore>();
builder.Services.AddSingleton<ImageStore>();
builder.Services.AddSingleton<BlobImageReader>();
builder.Services.AddHostedService<ServiceBusHeartbeatConsumer>();
if (builder.Configuration.GetValue<bool>("Images:Enabled"))
{
    builder.Services.AddHostedService<ServiceBusImageConsumer>();
}

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
app.MapGet(
    "/api/devices/{deviceName}/images",
    (string deviceName, ImageStore store) => Results.Ok(store.GetImages(deviceName)));
app.MapGet(
    "/api/images/{imageId}/content",
    async (
        string imageId,
        ImageStore store,
        BlobImageReader reader,
        CancellationToken cancellationToken) =>
    {
        if (store.GetImage(imageId) is not { } image)
        {
            return Results.NotFound(new { error = "image not found" });
        }

        var blob = await reader.OpenAsync(image.BlobName, cancellationToken);
        return blob is { } value
            ? Results.Stream(value.Content, value.ContentType)
            : Results.NotFound(new { error = "image content not found" });
    });

app.MapFallbackToFile("index.html");
app.Run();

public partial class Program;
