using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using System.Text.Json;
using Xunit;

namespace HeartbeatMonitor.Tests;

public sealed class ImageStoreTests
{
    [Fact]
    public async Task TryAddReturnsNewestImagesForDevice()
    {
        var store = CreateStore();
        Assert.True((await store.TryAddAsync(CreateImage("image-1", "edge-01", 1), default)).Accepted);
        Assert.True((await store.TryAddAsync(CreateImage("image-2", "edge-01", 2), default)).Accepted);
        Assert.True((await store.TryAddAsync(CreateImage("image-3", "edge-02", 3), default)).Accepted);

        var images = await store.GetImagesAsync("EDGE-01", default);

        Assert.Equal(2, images.Count);
        Assert.Equal("image-2", images[0].Id);
        Assert.Equal("image-1", images[1].Id);
    }

    [Fact]
    public async Task TryAddRejectsInvalidImageUpload()
    {
        var store = CreateStore();
        var image = CreateImage("image-1", "edge-01", 1);
        image.Width = 0;

        var result = await store.TryAddAsync(image, default);

        Assert.False(result.Accepted);
        Assert.Contains("positive", result.ValidationError);
    }

    [Fact]
    public void ImageUploadContractDeserializesCamelCaseEvent()
    {
        const string payload = """
            {
              "type": "ImageUpload",
              "id": "image-1",
              "deviceId": "edge-01",
              "hostname": "edge-host",
              "architecture": "arm64",
              "capturedAt": "2026-09-23T12:00:00Z",
              "uploadedAt": "2026-09-23T12:00:05Z",
              "fileName": "image-1.jpg",
              "blobName": "edge-01/image-1.jpg",
              "contentType": "image/jpeg",
              "width": 640,
              "height": 480,
              "commandId": "command-1",
              "correlationId": "11a3524e-86b3-4428-9f9a-abf51136f1ad",
              "deviceInfo": {
                "model": "Jetson Nano"
              }
            }
            """;

        var image = JsonSerializer.Deserialize<DeviceImage>(payload);

        Assert.NotNull(image);
        Assert.Equal("edge-01", image.DeviceId);
        Assert.Equal("command-1", image.CommandId);
        Assert.Equal(Guid.Parse("11a3524e-86b3-4428-9f9a-abf51136f1ad"), image.CorrelationId);
        Assert.Equal("Jetson Nano", image.DeviceInfo["model"].GetString());
    }

    private static DeviceImage CreateImage(string id, string deviceId, int minute) =>
        new()
        {
            Type = "ImageUpload",
            Id = id,
            DeviceId = deviceId,
            Hostname = deviceId,
            Architecture = "arm64",
            BlobName = $"{deviceId}/{id}.jpg",
            FileName = $"{id}.jpg",
            CapturedAt = new DateTimeOffset(2026, 9, 23, 12, minute, 0, TimeSpan.Zero),
            UploadedAt = new DateTimeOffset(2026, 9, 23, 12, minute, 5, TimeSpan.Zero),
            Width = 640,
            Height = 480,
            CorrelationId = Guid.Parse("11a3524e-86b3-4428-9f9a-abf51136f1ad")
        };

    private static ImageStore CreateStore() =>
        new(
            new TestDeviceDocumentStore(),
            Microsoft.Extensions.Options.Options.Create(
                new MonitorOptions
                {
                    ActiveDeviceTimeoutSeconds = 30,
                    MaxHeartbeatsPerDevice = 100,
                    MaxImagesPerDevice = 100
                }));
}
