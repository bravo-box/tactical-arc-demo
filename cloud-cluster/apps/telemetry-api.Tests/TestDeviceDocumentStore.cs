using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;

namespace HeartbeatMonitor.Tests;

internal sealed class TestDeviceDocumentStore : IDeviceDocumentStore
{
    private readonly Dictionary<string, DeviceDocument> _devices =
        new(StringComparer.OrdinalIgnoreCase);

    public Task<IReadOnlyList<DeviceDocument>> GetDevicesAsync(
        CancellationToken cancellationToken) =>
        Task.FromResult<IReadOnlyList<DeviceDocument>>([.. _devices.Values]);

    public Task<DeviceDocument?> GetDeviceAsync(
        string deviceId,
        CancellationToken cancellationToken)
    {
        _devices.TryGetValue(Normalize(deviceId), out var device);
        return Task.FromResult(device);
    }

    public Task<DeviceDocument> AddHeartbeatAsync(
        ReceivedHeartbeat heartbeat,
        int maxHeartbeats,
        CancellationToken cancellationToken)
    {
        var document = GetOrCreate(heartbeat.DeviceName);
        document.IpAddress = heartbeat.IpAddress;
        document.HealthStatus = heartbeat.HealthStatus;
        document.LastSeen = heartbeat.ReceivedAt;
        document.Location = heartbeat.Location ?? document.Location;
        if (heartbeat.Specs.Count > 0)
        {
            document.Specs = [.. heartbeat.Specs];
        }

        if (heartbeat.DeviceInfo.Count > 0)
        {
            document.DeviceInfo = new Dictionary<string, System.Text.Json.JsonElement>(
                heartbeat.DeviceInfo,
                StringComparer.OrdinalIgnoreCase);
        }

        document.Heartbeats.Insert(0, heartbeat);
        Trim(document.Heartbeats, maxHeartbeats);
        return Task.FromResult(document);
    }

    public Task<DeviceDocument> AddImageAsync(
        DeviceImage image,
        int maxImages,
        CancellationToken cancellationToken)
    {
        var document = GetOrCreate(image.DeviceId);
        document.Images.RemoveAll(
            existing => string.Equals(existing.Id, image.Id, StringComparison.OrdinalIgnoreCase));
        document.Images.Add(image);
        document.Images.Sort(
            static (left, right) => right.CapturedAt.CompareTo(left.CapturedAt));
        Trim(document.Images, maxImages);
        return Task.FromResult(document);
    }

    public Task<DeviceImage?> GetImageAsync(
        string imageId,
        CancellationToken cancellationToken) =>
        Task.FromResult(
            _devices.Values
                .SelectMany(device => device.Images)
                .FirstOrDefault(image => string.Equals(
                    image.Id,
                    imageId,
                    StringComparison.OrdinalIgnoreCase)));

    private DeviceDocument GetOrCreate(string deviceId)
    {
        var normalized = Normalize(deviceId);
        if (!_devices.TryGetValue(normalized, out var document))
        {
            document = new DeviceDocument
            {
                Id = normalized,
                DeviceId = normalized
            };
            _devices.Add(normalized, document);
        }

        return document;
    }

    private static string Normalize(string deviceId) =>
        deviceId.Trim().ToLowerInvariant();

    private static void Trim<T>(List<T> values, int maximum)
    {
        if (values.Count > maximum)
        {
            values.RemoveRange(maximum, values.Count - maximum);
        }
    }
}
