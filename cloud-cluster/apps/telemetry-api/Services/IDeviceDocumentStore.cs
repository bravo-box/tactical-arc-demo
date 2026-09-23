using HeartbeatMonitor.Models;

namespace HeartbeatMonitor.Services;

public interface IDeviceDocumentStore
{
    Task<IReadOnlyList<DeviceDocument>> GetDevicesAsync(CancellationToken cancellationToken);

    Task<DeviceDocument?> GetDeviceAsync(string deviceId, CancellationToken cancellationToken);

    Task<DeviceDocument> AddHeartbeatAsync(
        ReceivedHeartbeat heartbeat,
        int maxHeartbeats,
        CancellationToken cancellationToken);

    Task<DeviceDocument> AddImageAsync(
        DeviceImage image,
        int maxImages,
        CancellationToken cancellationToken);

    Task<DeviceImage?> GetImageAsync(string imageId, CancellationToken cancellationToken);
}
