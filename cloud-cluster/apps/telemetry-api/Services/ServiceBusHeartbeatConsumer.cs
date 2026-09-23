using System.Text.Json;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class ServiceBusHeartbeatConsumer : IHostedService, IAsyncDisposable
{
    private readonly ServiceBusOptions _options;
    private readonly HeartbeatStore _store;
    private readonly ILogger<ServiceBusHeartbeatConsumer> _logger;
    private ServiceBusClient? _client;
    private ServiceBusProcessor? _processor;

    public ServiceBusHeartbeatConsumer(
        IOptions<ServiceBusOptions> options,
        HeartbeatStore store,
        ILogger<ServiceBusHeartbeatConsumer> logger)
    {
        _options = options.Value;
        _store = store;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        _client = CreateClient();
        _processor = _client.CreateProcessor(
            _options.Topic,
            _options.Subscription,
            new ServiceBusProcessorOptions
            {
                AutoCompleteMessages = false,
                MaxConcurrentCalls = 1
            });
        _processor.ProcessMessageAsync += ProcessMessageAsync;
        _processor.ProcessErrorAsync += ProcessErrorAsync;

        await _processor.StartProcessingAsync(cancellationToken);
        _logger.LogInformation(
            "Listening for heartbeats on {Topic}/{Subscription}",
            _options.Topic,
            _options.Subscription);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_processor is not null)
        {
            await _processor.StopProcessingAsync(cancellationToken);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_processor is not null)
        {
            await _processor.DisposeAsync();
        }

        if (_client is not null)
        {
            await _client.DisposeAsync();
        }
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
            "Configure ServiceBus:ConnectionString or ServiceBus:FullyQualifiedNamespace.");
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        Heartbeat? heartbeat;
        try
        {
            heartbeat = args.Message.Body.ToObjectFromJson<Heartbeat>();
        }
        catch (JsonException exception)
        {
            _logger.LogWarning(exception, "Dead-lettering malformed heartbeat {MessageId}", args.Message.MessageId);
            await args.DeadLetterMessageAsync(
                args.Message,
                "InvalidJson",
                exception.Message,
                args.CancellationToken);
            return;
        }

        var result = heartbeat is null
            ? (Accepted: false, ValidationError: "message body is empty")
            : await _store.TryAddAsync(heartbeat, args.CancellationToken);
        if (!result.Accepted)
        {
            _logger.LogWarning(
                "Dead-lettering invalid heartbeat {MessageId}: {ValidationError}",
                args.Message.MessageId,
                result.ValidationError);
            await args.DeadLetterMessageAsync(
                args.Message,
                "InvalidHeartbeat",
                result.ValidationError,
                args.CancellationToken);
            return;
        }

        await args.CompleteMessageAsync(args.Message, args.CancellationToken);
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(
            args.Exception,
            "Service Bus receive failure from {ErrorSource} on {EntityPath}",
            args.ErrorSource,
            args.EntityPath);
        return Task.CompletedTask;
    }
}
