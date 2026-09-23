using System.Text.Json.Serialization;

namespace HeartbeatMonitor.Models;

public sealed record Heartbeat
{
    [JsonPropertyName("device-name")]
    public required string DeviceName { get; init; }

    [JsonPropertyName("ipAddress")]
    public required string IpAddress { get; init; }

    [JsonPropertyName("healthStatus")]
    public required string HealthStatus { get; init; }

    [JsonPropertyName("timestamp")]
    public required DateTimeOffset Timestamp { get; init; }
}

public sealed record ReceivedHeartbeat(
    string DeviceName,
    string IpAddress,
    string HealthStatus,
    DateTimeOffset Timestamp,
    DateTimeOffset ReceivedAt);

public sealed record DeviceSummary(
    string DeviceName,
    string IpAddress,
    string HealthStatus,
    DateTimeOffset LastSeen,
    bool IsActive);

public sealed record DeviceDetails(
    string DeviceName,
    string IpAddress,
    string HealthStatus,
    DateTimeOffset LastSeen,
    bool IsActive,
    IReadOnlyList<ReceivedHeartbeat> Heartbeats);
