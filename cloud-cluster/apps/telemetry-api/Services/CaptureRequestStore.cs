using HeartbeatMonitor.Models;

namespace HeartbeatMonitor.Services;

public sealed class CaptureRequestStore
{
    private readonly Dictionary<Guid, CaptureRequest> _requests = [];
    private readonly object _lock = new();

    public void AddQueued(Guid correlationId, string deviceName, DateTimeOffset requestedAt)
    {
        lock (_lock)
        {
            _requests[correlationId] = new CaptureRequest(
                correlationId,
                deviceName,
                "Queued",
                requestedAt,
                null,
                null);
        }
    }

    public void MarkUploaded(DeviceImage image)
    {
        lock (_lock)
        {
            var requestedAt = _requests.TryGetValue(image.CorrelationId, out var request)
                ? request.RequestedAt
                : image.CapturedAt;
            _requests[image.CorrelationId] = new CaptureRequest(
                image.CorrelationId,
                image.DeviceId,
                "Uploaded",
                requestedAt,
                image.UploadedAt,
                image.Id);
        }
    }

    public IReadOnlyList<CaptureRequest> GetForDevice(string deviceName)
    {
        lock (_lock)
        {
            return _requests.Values
                .Where(request => string.Equals(
                    request.DeviceName,
                    deviceName,
                    StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(request => request.RequestedAt)
                .ToArray();
        }
    }
}
