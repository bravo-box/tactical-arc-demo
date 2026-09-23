using System.Text.Json;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using HeartbeatMonitor.Models;
using Microsoft.Extensions.Options;

namespace HeartbeatMonitor.Services;

public sealed class ServiceBusImageConsumer : IHostedService, IAsyncDisposable
{
    private readonly ImageServiceBusOptions _options;
    private readonly ImageStore _store;
    private readonly ILogger<ServiceBusImageConsumer> _logger;
    private ServiceBusClient? _client;
    private ServiceBusProcessor? _processor;

    public ServiceBusImageConsumer(
        IOptions<ImageServiceBusOptions> options,
        ImageStore store,
        ILogger<ServiceBusImageConsumer> logger)
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
            "Listening for image uploads on {Topic}/{Subscription}",
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
            "Configure ImageServiceBus:ConnectionString or ImageServiceBus:FullyQualifiedNamespace.");
    }

    private async Task ProcessMessageAsync(ProcessMessageEventArgs args)
    {
        DeviceImage? image;
        try
        {
            image = args.Message.Body.ToObjectFromJson<DeviceImage>();
        }
        catch (JsonException exception)
        {
            await DeadLetterAsync(args, "InvalidJson", exception.Message);
            return;
        }

        var validationError = image is null ? "message body is empty" : string.Empty;
        if (image is null || !_store.TryAdd(image, out validationError))
        {
            await DeadLetterAsync(args, "InvalidImageUpload", validationError);
            return;
        }

        await args.CompleteMessageAsync(args.Message, args.CancellationToken);
    }

    private async Task DeadLetterAsync(
        ProcessMessageEventArgs args,
        string reason,
        string description)
    {
        _logger.LogWarning(
            "Dead-lettering invalid image event {MessageId}: {Description}",
            args.Message.MessageId,
            description);
        await args.DeadLetterMessageAsync(
            args.Message,
            reason,
            description,
            args.CancellationToken);
    }

    private Task ProcessErrorAsync(ProcessErrorEventArgs args)
    {
        _logger.LogError(
            args.Exception,
            "Image Service Bus receive failure from {ErrorSource} on {EntityPath}",
            args.ErrorSource,
            args.EntityPath);
        return Task.CompletedTask;
    }
}
