namespace HeartbeatMonitor.Services;

public sealed class MonitorOptions
{
    public const string SectionName = "Monitor";

    public int ActiveDeviceTimeoutSeconds { get; set; } = 30;

    public int MaxHeartbeatsPerDevice { get; set; } = 100;
}

public sealed class ServiceBusOptions
{
    public const string SectionName = "ServiceBus";

    public string? ConnectionString { get; set; }

    public string? FullyQualifiedNamespace { get; set; }

    public string Topic { get; set; } = "edge-heartbeat";

    public string Subscription { get; set; } = "heartbeat-monitor";
}
