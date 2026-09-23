using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class ImageStore
{
    private readonly IDeviceDocumentStore _documents;
    private readonly MonitorOptions _options;

    public ImageStore(
        IDeviceDocumentStore documents,
        IOptions<MonitorOptions> options)
    {
        _documents = documents;
        _options = options.Value;
        if (_options.MaxImagesPerDevice <= 0)
        {
            throw new InvalidOperationException("Monitor:MaxImagesPerDevice must be positive.");
        }
    }

    public async Task<(bool Accepted, string ValidationError)> TryAddAsync(
        DeviceImage image,
        CancellationToken cancellationToken)
    {
        var validationError = Validate(image);
        if (validationError is not null)
        {
            return (false, validationError);
        }

        image.DeviceId = image.DeviceId.Trim().ToLowerInvariant();
        await _documents.AddImageAsync(image, _options.MaxImagesPerDevice, cancellationToken);
        return (true, string.Empty);
    }

    public async Task<IReadOnlyList<DeviceImage>> GetImagesAsync(
        string deviceName,
        CancellationToken cancellationToken)
    {
        var device = await _documents.GetDeviceAsync(deviceName, cancellationToken);
        return device?.Images
            .OrderByDescending(image => image.CapturedAt)
            .ToArray() ?? [];
    }

    public Task<DeviceImage?> GetImageAsync(
        string imageId,
        CancellationToken cancellationToken) =>
        _documents.GetImageAsync(imageId, cancellationToken);

    private static string? Validate(DeviceImage image)
    {
        if (!string.Equals(image.Type, "ImageUpload", StringComparison.Ordinal))
        {
            return "type must be ImageUpload";
        }

        if (string.IsNullOrWhiteSpace(image.Id) ||
            string.IsNullOrWhiteSpace(image.DeviceId) ||
            string.IsNullOrWhiteSpace(image.BlobName))
        {
            return "id, deviceId, and blobName are required";
        }

        if (image.Width <= 0 || image.Height <= 0)
        {
            return "width and height must be positive";
        }

        if (image.CorrelationId == Guid.Empty)
        {
            return "correlationId must be a GUID";
        }

        return null;
    }
}
