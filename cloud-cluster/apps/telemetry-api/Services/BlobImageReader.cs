using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class BlobImageReader
{
    private readonly BlobContainerClient _container;

    public BlobImageReader(IOptions<StorageOptions> options)
    {
        var value = options.Value;
        if (!string.IsNullOrWhiteSpace(value.ConnectionString))
        {
            _container = new BlobContainerClient(value.ConnectionString, value.Container);
            return;
        }

        if (!string.IsNullOrWhiteSpace(value.AccountUrl))
        {
            _container = new BlobContainerClient(
                new Uri($"{value.AccountUrl.TrimEnd('/')}/{value.Container}"),
                new DefaultAzureCredential());
            return;
        }

        throw new InvalidOperationException(
            "Configure Storage:ConnectionString or Storage:AccountUrl.");
    }

    public async Task<(Stream Content, string ContentType)?> OpenAsync(
        string blobName,
        CancellationToken cancellationToken)
    {
        var blob = _container.GetBlobClient(blobName);
        if (!await blob.ExistsAsync(cancellationToken))
        {
            return null;
        }

        var download = await blob.DownloadStreamingAsync(cancellationToken: cancellationToken);
        return (download.Value.Content, download.Value.Details.ContentType);
    }
}
