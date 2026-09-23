using System.Net;
using HeartbeatMonitor.Models;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class CosmosDeviceDocumentStore : IDeviceDocumentStore
{
    private const int MaxWriteAttempts = 5;
    private readonly Container _container;

    public CosmosDeviceDocumentStore(CosmosClient client, IOptions<CosmosOptions> options)
    {
        var value = options.Value;
        if (string.IsNullOrWhiteSpace(value.Database))
        {
            throw new InvalidOperationException("Cosmos:Database is required.");
        }

        if (string.IsNullOrWhiteSpace(value.Container))
        {
            throw new InvalidOperationException("Cosmos:Container is required.");
        }

        _container = client.GetContainer(value.Database, value.Container);
    }

    public async Task<IReadOnlyList<DeviceDocument>> GetDevicesAsync(
        CancellationToken cancellationToken)
    {
        var devices = new List<DeviceDocument>();
        using var iterator = _container.GetItemQueryIterator<DeviceDocument>(
            new QueryDefinition("SELECT * FROM devices"));

        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            devices.AddRange(page);
        }

        return devices;
    }

    public async Task<DeviceDocument?> GetDeviceAsync(
        string deviceId,
        CancellationToken cancellationToken)
    {
        var normalizedDeviceId = NormalizeDeviceId(deviceId);
        try
        {
            var response = await _container.ReadItemAsync<DeviceDocument>(
                normalizedDeviceId,
                new PartitionKey(normalizedDeviceId),
                cancellationToken: cancellationToken);
            return response.Resource;
        }
        catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public Task<DeviceDocument> AddHeartbeatAsync(
        ReceivedHeartbeat heartbeat,
        int maxHeartbeats,
        CancellationToken cancellationToken)
    {
        var deviceId = NormalizeDeviceId(heartbeat.DeviceName);
        return MutateAsync(
            deviceId,
            document =>
            {
                document.IpAddress = heartbeat.IpAddress;
                document.HealthStatus = heartbeat.HealthStatus;
                document.LastSeen = heartbeat.ReceivedAt;
                if (heartbeat.Location is not null)
                {
                    document.Location = heartbeat.Location;
                }

                if (heartbeat.Specs.Count > 0)
                {
                    document.Specs = [.. heartbeat.Specs];
                }

                document.Heartbeats.Insert(0, heartbeat);
                Trim(document.Heartbeats, maxHeartbeats);
            },
            cancellationToken);
    }

    public Task<DeviceDocument> AddImageAsync(
        DeviceImage image,
        int maxImages,
        CancellationToken cancellationToken)
    {
        var deviceId = NormalizeDeviceId(image.DeviceId);
        return MutateAsync(
            deviceId,
            document =>
            {
                document.Images.RemoveAll(
                    existing => string.Equals(
                        existing.Id,
                        image.Id,
                        StringComparison.OrdinalIgnoreCase));
                document.Images.Add(image);
                document.Images.Sort(
                    static (left, right) => right.CapturedAt.CompareTo(left.CapturedAt));
                Trim(document.Images, maxImages);
            },
            cancellationToken);
    }

    public async Task<DeviceImage?> GetImageAsync(
        string imageId,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT VALUE image FROM device JOIN image IN device.images WHERE image.id = @imageId")
            .WithParameter("@imageId", imageId);
        using var iterator = _container.GetItemQueryIterator<DeviceImage>(query);

        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            var image = page.FirstOrDefault();
            if (image is not null)
            {
                return image;
            }
        }

        return null;
    }

    private async Task<DeviceDocument> MutateAsync(
        string deviceId,
        Action<DeviceDocument> mutation,
        CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= MaxWriteAttempts; attempt++)
        {
            var document = await GetDeviceAsync(deviceId, cancellationToken);
            var isNew = document is null;
            document ??= new DeviceDocument
            {
                Id = deviceId,
                DeviceId = deviceId
            };
            mutation(document);

            try
            {
                if (isNew)
                {
                    var created = await _container.CreateItemAsync(
                        document,
                        new PartitionKey(deviceId),
                        cancellationToken: cancellationToken);
                    return created.Resource;
                }

                var replaced = await _container.ReplaceItemAsync(
                    document,
                    document.Id,
                    new PartitionKey(deviceId),
                    new ItemRequestOptions { IfMatchEtag = document.ETag },
                    cancellationToken);
                return replaced.Resource;
            }
            catch (CosmosException exception)
                when (exception.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed &&
                      attempt < MaxWriteAttempts)
            {
                continue;
            }
        }

        throw new InvalidOperationException(
            $"Could not update device '{deviceId}' after {MaxWriteAttempts} concurrency retries.");
    }

    private static string NormalizeDeviceId(string deviceId) =>
        deviceId.Trim().ToLowerInvariant();

    private static void Trim<T>(List<T> values, int maximum)
    {
        if (values.Count > maximum)
        {
            values.RemoveRange(maximum, values.Count - maximum);
        }
    }
}
