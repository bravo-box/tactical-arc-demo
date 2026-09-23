using System.Text.Json;
using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class HeartbeatStore
{
    private static readonly HashSet<string> ValidStatuses =
        new(StringComparer.OrdinalIgnoreCase) { "Green", "Yellow", "Red" };

    private readonly IDeviceDocumentStore _documents;
    private readonly MonitorOptions _options;
    private readonly TimeProvider _timeProvider;

    public HeartbeatStore(
        IDeviceDocumentStore documents,
        IOptions<MonitorOptions> options,
        TimeProvider timeProvider)
    {
        _documents = documents;
        _options = options.Value;
        _timeProvider = timeProvider;

        if (_options.ActiveDeviceTimeoutSeconds <= 0)
        {
            throw new InvalidOperationException("Monitor:ActiveDeviceTimeoutSeconds must be positive.");
        }

        if (_options.MaxHeartbeatsPerDevice <= 0)
        {
            throw new InvalidOperationException("Monitor:MaxHeartbeatsPerDevice must be positive.");
        }
    }

    public async Task<(bool Accepted, string ValidationError)> TryAddAsync(
        Heartbeat heartbeat,
        CancellationToken cancellationToken)
    {
        var location = heartbeat.Location ?? ExtractLocation(heartbeat.DeviceInfo);
        var specs = heartbeat.Specs?.Select(
                spec => new DeviceSpec(spec.Name.Trim(), spec.Value.Trim())).ToArray()
            ?? ExtractSpecs(heartbeat.DeviceInfo);
        var validationError = Validate(heartbeat, location, specs);
        if (validationError is not null)
        {
            return (false, validationError);
        }

        var received = new ReceivedHeartbeat(
            heartbeat.DeviceName.Trim().ToLowerInvariant(),
            heartbeat.IpAddress.Trim(),
            NormalizeStatus(heartbeat.HealthStatus),
            heartbeat.Timestamp,
            _timeProvider.GetUtcNow(),
            location,
            specs,
            heartbeat.DeviceInfo);

        await _documents.AddHeartbeatAsync(
            received,
            _options.MaxHeartbeatsPerDevice,
            cancellationToken);
        return (true, string.Empty);
    }

    public async Task<IReadOnlyList<DeviceSummary>> GetDevicesAsync(
        CancellationToken cancellationToken)
    {
        var now = _timeProvider.GetUtcNow();
        var devices = await _documents.GetDevicesAsync(cancellationToken);
        return devices
            .Select(device => new DeviceSummary(
                device.DeviceId,
                device.IpAddress,
                device.HealthStatus,
                device.LastSeen,
                IsActive(device.LastSeen, now)))
            .OrderByDescending(summary => summary.IsActive)
            .ThenBy(summary => summary.DeviceName, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public async Task<DeviceDetails?> GetDeviceAsync(
        string deviceName,
        CancellationToken cancellationToken)
    {
        var device = await _documents.GetDeviceAsync(deviceName, cancellationToken);
        return device is null
            ? null
            : new DeviceDetails(
                device.DeviceId,
                device.IpAddress,
                device.HealthStatus,
                device.LastSeen,
                IsActive(device.LastSeen, _timeProvider.GetUtcNow()),
                device.Location,
                device.Specs,
                device.DeviceInfo,
                device.Heartbeats);
    }

    private static string? Validate(
        Heartbeat heartbeat,
        DeviceLocation? location,
        IReadOnlyList<DeviceSpec> specs)
    {
        if (string.IsNullOrWhiteSpace(heartbeat.DeviceName))
        {
            return "device-name is required";
        }

        if (string.IsNullOrWhiteSpace(heartbeat.IpAddress))
        {
            return "ipAddress is required";
        }

        if (!ValidStatuses.Contains(heartbeat.HealthStatus))
        {
            return "healthStatus must be Green, Yellow, or Red";
        }

        if (location is { Latitude: < -90 or > 90 })
        {
            return "location.latitude must be between -90 and 90";
        }

        if (location is { Longitude: < -180 or > 180 })
        {
            return "location.longitude must be between -180 and 180";
        }

        if (specs.Any(
                spec => string.IsNullOrWhiteSpace(spec.Name) ||
                        string.IsNullOrWhiteSpace(spec.Value)))
        {
            return "spec names and values must be non-empty";
        }

        return null;
    }

    private static DeviceLocation? ExtractLocation(
        IReadOnlyDictionary<string, JsonElement> deviceInfo)
    {
        if (!deviceInfo.TryGetValue("location", out var location) ||
            location.ValueKind != JsonValueKind.Object ||
            !location.TryGetProperty("latitude", out var latitude) ||
            !location.TryGetProperty("longitude", out var longitude) ||
            !latitude.TryGetDouble(out var latitudeValue) ||
            !longitude.TryGetDouble(out var longitudeValue))
        {
            return null;
        }

        return new DeviceLocation
        {
            Latitude = latitudeValue,
            Longitude = longitudeValue
        };
    }

    private static IReadOnlyList<DeviceSpec> ExtractSpecs(
        IReadOnlyDictionary<string, JsonElement> deviceInfo) =>
        deviceInfo
            .Where(pair =>
                !string.Equals(pair.Key, "deviceId", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(pair.Key, "location", StringComparison.OrdinalIgnoreCase))
            .Select(pair => new DeviceSpec(pair.Key, FormatSpecValue(pair.Value)))
            .ToArray();

    private static string FormatSpecValue(JsonElement value) =>
        value.ValueKind == JsonValueKind.String
            ? value.GetString() ?? string.Empty
            : value.GetRawText();

    private bool IsActive(DateTimeOffset lastSeen, DateTimeOffset now) =>
        now - lastSeen <= TimeSpan.FromSeconds(_options.ActiveDeviceTimeoutSeconds);

    private static string NormalizeStatus(string status) =>
        string.Concat(status[..1].ToUpperInvariant(), status[1..].ToLowerInvariant());
}
