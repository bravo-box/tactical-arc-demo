using System.Text.Json;
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

    [JsonPropertyName("location")]
    public DeviceLocation? Location { get; init; }

    [JsonPropertyName("specs")]
    public IReadOnlyList<DeviceSpec>? Specs { get; init; }

    [JsonPropertyName("deviceInfo")]
    public Dictionary<string, JsonElement> DeviceInfo { get; init; } = [];
}

public sealed record DeviceLocation(double Latitude, double Longitude);

public sealed record DeviceSpec(string Name, string Value);

public sealed record ReceivedHeartbeat(
    string DeviceName,
    string IpAddress,
    string HealthStatus,
    DateTimeOffset Timestamp,
    DateTimeOffset ReceivedAt,
    DeviceLocation? Location,
    IReadOnlyList<DeviceSpec> Specs,
    IReadOnlyDictionary<string, JsonElement> DeviceInfo);

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
    DeviceLocation? Location,
    IReadOnlyList<DeviceSpec> Specs,
    IReadOnlyDictionary<string, JsonElement> DeviceInfo,
    IReadOnlyList<ReceivedHeartbeat> Heartbeats);
