namespace HeartbeatMonitor.Models;

public sealed class DeviceDocument
{
    public required string Id { get; init; }

    public required string DeviceId { get; init; }

    public string IpAddress { get; set; } = string.Empty;

    public string HealthStatus { get; set; } = "Red";

    public DateTimeOffset LastSeen { get; set; }

    public DeviceLocation? Location { get; set; }

    public List<DeviceSpec> Specs { get; set; } = [];

    public List<ReceivedHeartbeat> Heartbeats { get; set; } = [];

    public List<DeviceImage> Images { get; set; } = [];

    [Newtonsoft.Json.JsonProperty(PropertyName = "_etag")]
    public string? ETag { get; set; }
}
