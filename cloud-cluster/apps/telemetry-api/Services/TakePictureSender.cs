using Azure.Identity;
using Azure.Messaging.ServiceBus;
using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class TakePictureSender : IAsyncDisposable
{
    private readonly CameraCommandOptions _options;
    private readonly CaptureRequestStore _store;
    private readonly TimeProvider _timeProvider;
    private readonly ServiceBusClient _client;
    private readonly ServiceBusSender _sender;

    public TakePictureSender(
        IOptions<CameraCommandOptions> options,
        CaptureRequestStore store,
        TimeProvider timeProvider)
    {
        _options = options.Value;
        _store = store;
        _timeProvider = timeProvider;
        _client = CreateClient();
        _sender = _client.CreateSender(_options.Queue);
    }

    public async Task<CaptureRequest> SendAsync(
        string deviceName,
        CancellationToken cancellationToken)
    {
        var correlationId = Guid.NewGuid();
        var requestedAt = _timeProvider.GetUtcNow();
        var message = new ServiceBusMessage(
            BinaryData.FromObjectAsJson(
                new
                {
                    type = "TakePicture",
                    id = correlationId,
                    correlationId,
                    deviceId = deviceName,
                    requestedAt
                }))
        {
            ContentType = "application/json",
            Subject = "TakePicture",
            MessageId = correlationId.ToString(),
            CorrelationId = correlationId.ToString(),
            SessionId = deviceName
        };

        await _sender.SendMessageAsync(message, cancellationToken);
        _store.AddQueued(correlationId, deviceName, requestedAt);
        return _store.GetForDevice(deviceName).First(request => request.CorrelationId == correlationId);
    }

    public async ValueTask DisposeAsync()
    {
        await _sender.DisposeAsync();
        await _client.DisposeAsync();
    }

    private ServiceBusClient CreateClient()
    {
        if (!string.IsNullOrWhiteSpace(_options.ConnectionString))
        {
            return new ServiceBusClient(_options.ConnectionString);
        }

        if (!string.IsNullOrWhiteSpace(_options.FullyQualifiedNamespace))
        {
            return new ServiceBusClient(
                _options.FullyQualifiedNamespace,
                new DefaultAzureCredential());
        }

        throw new InvalidOperationException(
            "Configure CameraCommands:ConnectionString or CameraCommands:FullyQualifiedNamespace.");
    }
}
