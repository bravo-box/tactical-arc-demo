using HeartbeatMonitor.Models;
using HeartbeatMonitor.Services;
using Xunit;

namespace HeartbeatMonitor.Tests;

public sealed class CaptureRequestStoreTests
{
    [Fact]
    public void MarkUploadedCompletesMatchingQueuedRequest()
    {
        var correlationId = Guid.NewGuid();
        var requestedAt = DateTimeOffset.UtcNow.AddSeconds(-5);
        var store = new CaptureRequestStore();
        store.AddQueued(correlationId, "edge-01", requestedAt);

        store.MarkUploaded(
            new DeviceImage
            {
                CorrelationId = correlationId,
                DeviceId = "edge-01",
                Id = "image-1",
                CapturedAt = requestedAt.AddSeconds(1),
                UploadedAt = requestedAt.AddSeconds(4)
            });

        var request = Assert.Single(store.GetForDevice("EDGE-01"));
        Assert.Equal("Uploaded", request.Status);
        Assert.Equal("image-1", request.ImageId);
        Assert.Equal(requestedAt.AddSeconds(4), request.CompletedAt);
    }

    [Fact]
    public void MarkUploadedRecoversRequestMissingAfterRestart()
    {
        var correlationId = Guid.NewGuid();
        var store = new CaptureRequestStore();

        store.MarkUploaded(
            new DeviceImage
            {
                CorrelationId = correlationId,
                DeviceId = "edge-01",
                Id = "image-1",
                CapturedAt = DateTimeOffset.UtcNow,
                UploadedAt = DateTimeOffset.UtcNow.AddSeconds(2)
            });

        Assert.Equal("Uploaded", Assert.Single(store.GetForDevice("edge-01")).Status);
    }
}
