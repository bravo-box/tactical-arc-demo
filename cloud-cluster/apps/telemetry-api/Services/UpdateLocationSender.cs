using Azure.Identity;
using Azure.Messaging.ServiceBus;
using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class UpdateLocationSender : IAsyncDisposable
{
    private readonly LocationCommandOptions _options;
    private readonly TimeProvider _timeProvider;
    private readonly ServiceBusClient _client;
    private readonly ServiceBusSender _sender;

    public UpdateLocationSender(
        IOptions<LocationCommandOptions> options,
        TimeProvider timeProvider)
    {
        _options = options.Value;
        _timeProvider = timeProvider;
        _client = CreateClient();
        _sender = _client.CreateSender(_options.Queue);
    }

    public async Task<object> SendAsync(
        string deviceName,
        UpdateLocationRequest location,
        CancellationToken cancellationToken)
    {
        var correlationId = Guid.NewGuid();
        var requestedAt = _timeProvider.GetUtcNow();
        var message = new ServiceBusMessage(
            BinaryData.FromObjectAsJson(
                new
                {
                    type = "UpdateLocationRequest",
                    correlationId,
                    deviceId = deviceName,
                    requestedAt,
                    location
                }))
        {
            ContentType = "application/json",
            Subject = "UpdateLocationRequest",
            MessageId = correlationId.ToString(),
            CorrelationId = correlationId.ToString(),
            SessionId = deviceName
        };

        await _sender.SendMessageAsync(message, cancellationToken);
        return new { correlationId, deviceName, requestedAt, location };
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
            "Configure LocationCommands:ConnectionString or LocationCommands:FullyQualifiedNamespace.");
    }
}
