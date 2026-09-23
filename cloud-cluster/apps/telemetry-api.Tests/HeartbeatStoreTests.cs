using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using Microsoft.Extensions.Options;
using System.Text.Json;
using Xunit;

namespace HeartbeatMonitor.Tests;

public sealed class HeartbeatStoreTests
{
    [Fact]
    public void TryAddTracksLatestDetailsAndBoundsHistory()
    {
        var store = CreateStore(maxHeartbeats: 2);

        Assert.True(store.TryAdd(CreateHeartbeat("green"), out _));
        Assert.True(store.TryAdd(CreateHeartbeat("Yellow"), out _));
        Assert.True(store.TryAdd(CreateHeartbeat("Red"), out _));

        var device = Assert.IsType<DeviceDetails>(store.GetDevice("edge-01"));
        Assert.Equal("Red", device.HealthStatus);
        Assert.Equal(2, device.Heartbeats.Count);
        Assert.True(device.IsActive);
        Assert.Equal("Jetson Nano", device.DeviceInfo["model"].GetString());
    }

    [Fact]
    public void TryAddRejectsUnknownHealthStatus()
    {
        var store = CreateStore();

        var accepted = store.TryAdd(CreateHeartbeat("Unknown"), out var error);

        Assert.False(accepted);
        Assert.Contains("Green, Yellow, or Red", error);
    }

    private static HeartbeatStore CreateStore(int maxHeartbeats = 100) =>
        new(
            Options.Create(
                new MonitorOptions
                {
                    ActiveDeviceTimeoutSeconds = 30,
                    MaxHeartbeatsPerDevice = maxHeartbeats
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
            }
        };
}
