using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using Microsoft.Extensions.Options;
using System.Text.Json;
using Xunit;

namespace HeartbeatMonitor.Tests;

public sealed class HeartbeatStoreTests
{
    [Fact]
    public async Task TryAddTracksLatestDetailsAndBoundsHistory()
    {
        var store = CreateStore(maxHeartbeats: 2);

        Assert.True((await store.TryAddAsync(CreateHeartbeat("green"), default)).Accepted);
        Assert.True((await store.TryAddAsync(CreateHeartbeat("Yellow"), default)).Accepted);
        Assert.True((await store.TryAddAsync(CreateHeartbeat("Red"), default)).Accepted);

        var device = Assert.IsType<DeviceDetails>(
            await store.GetDeviceAsync("EDGE-01", default));
        Assert.Equal("Red", device.HealthStatus);
        Assert.Equal(2, device.Heartbeats.Count);
        Assert.True(device.IsActive);
        Assert.Equal("Jetson Nano", device.DeviceInfo["model"].GetString());
        Assert.Equal(47.61, device.Location?.Latitude);
        Assert.Equal(-122.33, device.Location?.Longitude);
    }

    [Fact]
    public async Task TryAddRejectsUnknownHealthStatus()
    {
        var store = CreateStore();

        var result = await store.TryAddAsync(CreateHeartbeat("Unknown"), default);

        Assert.False(result.Accepted);
        Assert.Contains("Green, Yellow, or Red", result.ValidationError);
    }

    [Fact]
    public async Task TryAddDerivesLocationAndSpecsFromDeviceInfo()
    {
        var store = CreateStore();
        var heartbeat = CreateHeartbeat("Green") with
        {
            Location = null,
            DeviceInfo = new()
            {
                ["deviceId"] = JsonSerializer.SerializeToElement("edge-01"),
                ["architecture"] = JsonSerializer.SerializeToElement("arm64"),
                ["location"] = JsonSerializer.SerializeToElement(
                    new { latitude = 38.8977, longitude = -77.0365 })
            }
        };

        Assert.True((await store.TryAddAsync(heartbeat, default)).Accepted);

        var device = Assert.IsType<DeviceDetails>(
            await store.GetDeviceAsync("edge-01", default));
        Assert.Equal(38.8977, device.Location?.Latitude);
        Assert.Equal("arm64", Assert.Single(device.Specs).Value);
    }

    private static HeartbeatStore CreateStore(int maxHeartbeats = 100) =>
        new(
            new TestDeviceDocumentStore(),
            Options.Create(
                new MonitorOptions
                {
                    ActiveDeviceTimeoutSeconds = 30,
                    MaxHeartbeatsPerDevice = maxHeartbeats,
                    MaxImagesPerDevice = 100
                }),
            TimeProvider.System);

    private static Heartbeat CreateHeartbeat(string status) =>
        new()
        {
            DeviceName = "edge-01",
            IpAddress = "10.0.0.5",
            HealthStatus = status,
            Timestamp = DateTimeOffset.UtcNow,
            DeviceInfo = new()
            {
                ["model"] = JsonSerializer.SerializeToElement("Jetson Nano")
            },
            Location = new DeviceLocation
            {
                Latitude = 47.61,
                Longitude = -122.33
            }
        };
}
