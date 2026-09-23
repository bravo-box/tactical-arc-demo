using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using Microsoft.Extensions.Options;
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
    public async Task TryAddPersistsLocationAndDeviceSpecs()
    {
        var store = CreateStore();
        var heartbeat = CreateHeartbeat("Green") with
        {
            Location = new DeviceLocation(38.8977, -77.0365),
            Specs = [new DeviceSpec("architecture", "arm64")]
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
            Timestamp = DateTimeOffset.UtcNow
        };
}
