using System.Collections.Concurrent;
using HeartbeatMonitor.Models;

namespace HeartbeatMonitor.Services;

public sealed class ImageStore
{
    private readonly ConcurrentDictionary<string, DeviceImage> _images =
        new(StringComparer.OrdinalIgnoreCase);

    public bool TryAdd(DeviceImage image, out string validationError)
    {
        if (!string.Equals(image.Type, "ImageUpload", StringComparison.Ordinal))
        {
            validationError = "type must be ImageUpload";
            return false;
        }

        if (string.IsNullOrWhiteSpace(image.Id) ||
            string.IsNullOrWhiteSpace(image.DeviceId) ||
            string.IsNullOrWhiteSpace(image.BlobName))
        {
            validationError = "id, deviceId, and blobName are required";
            return false;
        }

        if (image.Width <= 0 || image.Height <= 0)
        {
            validationError = "width and height must be positive";
            return false;
        }

        _images[image.Id] = image;
        validationError = string.Empty;
        return true;
    }

    public IReadOnlyList<DeviceImage> GetImages(string deviceName) =>
        _images.Values
            .Where(image => string.Equals(image.DeviceId, deviceName, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(image => image.CapturedAt)
            .ToArray();

    public DeviceImage? GetImage(string imageId) =>
        _images.TryGetValue(imageId, out var image) ? image : null;
}
