using Azure.Core;
using Azure.Identity;
using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);
var imagesEnabled = builder.Configuration.GetValue<bool>("Images:Enabled");
var locationUpdatesEnabled =
    builder.Configuration.GetValue<bool>("LocationCommands:Enabled");

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
builder.Services.Configure<CameraCommandOptions>(
    builder.Configuration.GetSection(CameraCommandOptions.SectionName));
builder.Services.Configure<LocationCommandOptions>(
    builder.Configuration.GetSection(LocationCommandOptions.SectionName));
builder.Services.Configure<CosmosOptions>(
    builder.Configuration.GetSection(CosmosOptions.SectionName));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<TokenCredential, DefaultAzureCredential>();
builder.Services.AddSingleton(
    serviceProvider =>
    {
        var options = builder.Configuration
            .GetSection(CosmosOptions.SectionName)
            .Get<CosmosOptions>() ?? new CosmosOptions();
        if (!Uri.TryCreate(options.Endpoint, UriKind.Absolute, out var endpoint))
        {
            throw new InvalidOperationException("Cosmos:Endpoint must be an absolute URI.");
        }

        return new CosmosClient(
            endpoint.ToString(),
            serviceProvider.GetRequiredService<TokenCredential>(),
            new CosmosClientOptions
            {
                ApplicationName = "tactical-arc-telemetry-api",
                SerializerOptions = new CosmosSerializationOptions
                {
                    PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
                }
            });
    });
builder.Services.AddSingleton<IDeviceDocumentStore, CosmosDeviceDocumentStore>();
builder.Services.AddSingleton<HeartbeatStore>();
builder.Services.AddSingleton<ImageStore>();
builder.Services.AddSingleton<CaptureRequestStore>();
builder.Services.AddSingleton<BlobImageReader>();
builder.Services.AddHostedService<ServiceBusHeartbeatConsumer>();
if (imagesEnabled)
{
    builder.Services.AddSingleton<TakePictureSender>();
    builder.Services.AddHostedService<ServiceBusImageConsumer>();
}
if (locationUpdatesEnabled)
{
    builder.Services.AddSingleton<UpdateLocationSender>();
}

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));
app.MapGet("/readyz", () => Results.Ok(new { status = "ready" }));
app.MapGet(
    "/api/features",
    () => Results.Ok(new { imagesEnabled, locationUpdatesEnabled }));
app.MapGet(
    "/api/devices",
    async (HeartbeatStore store, CancellationToken cancellationToken) =>
        Results.Ok(await store.GetDevicesAsync(cancellationToken)));
app.MapGet(
    "/api/devices/{deviceName}",
    async (string deviceName, HeartbeatStore store, CancellationToken cancellationToken) =>
        await store.GetDeviceAsync(deviceName, cancellationToken) is { } device
            ? Results.Ok(device)
            : Results.NotFound(new { error = "device not found" }));
app.MapGet(
    "/api/devices/{deviceName}/images",
    async (string deviceName, ImageStore store, CancellationToken cancellationToken) =>
        Results.Ok(await store.GetImagesAsync(deviceName, cancellationToken)));
app.MapGet(
    "/api/devices/{deviceName}/capture-requests",
    (string deviceName, CaptureRequestStore store) => Results.Ok(store.GetForDevice(deviceName)));
if (imagesEnabled)
{
    app.MapPost(
        "/api/devices/{deviceName}/capture-requests",
        async (
            string deviceName,
            HeartbeatStore devices,
            TakePictureSender sender,
            CancellationToken cancellationToken) =>
        {
            if (await devices.GetDeviceAsync(deviceName, cancellationToken) is null)
            {
                return Results.NotFound(new { error = "device not found" });
            }

            var request = await sender.SendAsync(deviceName, cancellationToken);
            return Results.Accepted(
                $"/api/devices/{Uri.EscapeDataString(deviceName)}/capture-requests",
                request);
        });
}
if (locationUpdatesEnabled)
{
    app.MapPost(
        "/api/devices/{deviceName}/location",
        async (
            string deviceName,
            UpdateLocationRequest location,
            HeartbeatStore devices,
            UpdateLocationSender sender,
            CancellationToken cancellationToken) =>
        {
            if (await devices.GetDeviceAsync(deviceName, cancellationToken) is null)
            {
                return Results.NotFound(new { error = "device not found" });
            }

            if (!double.IsFinite(location.Latitude) ||
                location.Latitude is < -90 or > 90)
            {
                return Results.BadRequest(
                    new { error = "latitude must be between -90 and 90" });
            }

            if (!double.IsFinite(location.Longitude) ||
                location.Longitude is < -180 or > 180)
            {
                return Results.BadRequest(
                    new { error = "longitude must be between -180 and 180" });
            }

            var request = await sender.SendAsync(
                deviceName, location, cancellationToken);
            return Results.Accepted(
                $"/api/devices/{Uri.EscapeDataString(deviceName)}",
                request);
        });
}
app.MapGet(
    "/api/images/{imageId}/content",
    async (
        string imageId,
        ImageStore store,
        BlobImageReader reader,
        CancellationToken cancellationToken) =>
    {
        if (await store.GetImageAsync(imageId, cancellationToken) is not { } image)
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
