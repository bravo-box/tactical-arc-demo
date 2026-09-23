using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using System.Text.Json;
using Xunit;

namespace HeartbeatMonitor.Tests;

public sealed class ImageStoreTests
{
    [Fact]
    public void TryAddReturnsNewestImagesForDevice()
    {
        var store = new ImageStore();
        Assert.True(store.TryAdd(CreateImage("image-1", "edge-01", 1), out _));
        Assert.True(store.TryAdd(CreateImage("image-2", "edge-01", 2), out _));
        Assert.True(store.TryAdd(CreateImage("image-3", "edge-02", 3), out _));

        var images = store.GetImages("EDGE-01");

        Assert.Equal(2, images.Count);
        Assert.Equal("image-2", images[0].Id);
        Assert.Equal("image-1", images[1].Id);
    }

    [Fact]
    public void TryAddRejectsInvalidImageUpload()
    {
        var store = new ImageStore();
        var image = CreateImage("image-1", "edge-01", 1);
        image.Width = 0;

        var accepted = store.TryAdd(image, out var error);

        Assert.False(accepted);
        Assert.Contains("positive", error);
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
              "commandId": "command-1"
            }
            """;

        var image = JsonSerializer.Deserialize<DeviceImage>(payload);

        Assert.NotNull(image);
        Assert.Equal("edge-01", image.DeviceId);
        Assert.Equal("command-1", image.CommandId);
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
            Height = 480
        };
}
