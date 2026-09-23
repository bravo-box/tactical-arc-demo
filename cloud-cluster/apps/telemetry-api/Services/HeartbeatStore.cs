using System.Collections.Concurrent;
using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class HeartbeatStore
{
    private static readonly HashSet<string> ValidStatuses =
        new(StringComparer.OrdinalIgnoreCase) { "Green", "Yellow", "Red" };

    private readonly ConcurrentDictionary<string, DeviceState> _devices =
        new(StringComparer.OrdinalIgnoreCase);
    private readonly MonitorOptions _options;
    private readonly TimeProvider _timeProvider;

    public HeartbeatStore(IOptions<MonitorOptions> options, TimeProvider timeProvider)
    {
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

    public bool TryAdd(Heartbeat heartbeat, out string validationError)
    {
        if (string.IsNullOrWhiteSpace(heartbeat.DeviceName))
        {
            validationError = "device-name is required";
            return false;
        }

        if (string.IsNullOrWhiteSpace(heartbeat.IpAddress))
        {
            validationError = "ipAddress is required";
            return false;
        }

        if (!ValidStatuses.Contains(heartbeat.HealthStatus))
        {
            validationError = "healthStatus must be Green, Yellow, or Red";
            return false;
        }

        var received = new ReceivedHeartbeat(
            heartbeat.DeviceName.Trim(),
            heartbeat.IpAddress.Trim(),
            NormalizeStatus(heartbeat.HealthStatus),
            heartbeat.Timestamp,
            _timeProvider.GetUtcNow(),
            heartbeat.DeviceInfo);

        var state = _devices.GetOrAdd(received.DeviceName, _ => new DeviceState());
        lock (state)
        {
            state.Heartbeats.AddFirst(received);
            while (state.Heartbeats.Count > _options.MaxHeartbeatsPerDevice)
            {
                state.Heartbeats.RemoveLast();
            }
        }

        validationError = string.Empty;
        return true;
    }

    public IReadOnlyList<DeviceSummary> GetDevices()
    {
        var now = _timeProvider.GetUtcNow();
        return _devices
            .Select(pair => CreateSummary(pair.Key, pair.Value, now))
            .Where(summary => summary is not null)
            .Cast<DeviceSummary>()
            .OrderByDescending(summary => summary.IsActive)
            .ThenBy(summary => summary.DeviceName, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public DeviceDetails? GetDevice(string deviceName)
    {
        if (!_devices.TryGetValue(deviceName, out var state))
        {
            return null;
        }

        lock (state)
        {
            if (state.Heartbeats.First is not { Value: var latest })
            {
                return null;
            }

            return new DeviceDetails(
                latest.DeviceName,
                latest.IpAddress,
                latest.HealthStatus,
                latest.ReceivedAt,
                IsActive(latest.ReceivedAt, _timeProvider.GetUtcNow()),
                latest.DeviceInfo,
                state.Heartbeats.ToArray());
        }
    }

    private DeviceSummary? CreateSummary(
        string deviceName,
        DeviceState state,
        DateTimeOffset now)
    {
        lock (state)
        {
            if (state.Heartbeats.First is not { Value: var latest })
            {
                return null;
            }

            return new DeviceSummary(
                deviceName,
                latest.IpAddress,
                latest.HealthStatus,
                latest.ReceivedAt,
                IsActive(latest.ReceivedAt, now));
        }
    }

    private bool IsActive(DateTimeOffset lastSeen, DateTimeOffset now) =>
        now - lastSeen <= TimeSpan.FromSeconds(_options.ActiveDeviceTimeoutSeconds);

    private static string NormalizeStatus(string status) =>
        string.Concat(status[..1].ToUpperInvariant(), status[1..].ToLowerInvariant());

    private sealed class DeviceState
    {
        public LinkedList<ReceivedHeartbeat> Heartbeats { get; } = [];
    }
}
