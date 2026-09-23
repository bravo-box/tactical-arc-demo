namespace HeartbeatMonitor.Models;

public sealed record CaptureRequest(
    Guid CorrelationId,
    string DeviceName,
    string Status,
    DateTimeOffset RequestedAt,
    DateTimeOffset? CompletedAt,
    string? ImageId);
