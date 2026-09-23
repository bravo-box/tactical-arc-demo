using System.Text.Json.Serialization;

namespace HeartbeatMonitor.Models;

public sealed record DeviceLocation
{
    [JsonPropertyName("latitude")]
    public required double Latitude { get; init; }

    [JsonPropertyName("longitude")]
    public required double Longitude { get; init; }
}

public sealed record UpdateLocationRequest
{
    [JsonPropertyName("latitude")]
    public required double Latitude { get; init; }

    [JsonPropertyName("longitude")]
    public required double Longitude { get; init; }
}
