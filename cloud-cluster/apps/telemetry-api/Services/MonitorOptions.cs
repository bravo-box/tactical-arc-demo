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

public sealed class ImageServiceBusOptions
{
    public const string SectionName = "ImageServiceBus";

    public string? ConnectionString { get; set; }

    public string? FullyQualifiedNamespace { get; set; }

    public string Topic { get; set; } = "image-upload";

    public string Subscription { get; set; } = "image-web";
}

public sealed class StorageOptions
{
    public const string SectionName = "Storage";

    public string? ConnectionString { get; set; }

    public string? AccountUrl { get; set; }

    public string Container { get; set; } = "device-images";
}

public sealed class ImageFeatureOptions
{
    public const string SectionName = "Images";

    public bool Enabled { get; set; }
}

public sealed class CameraCommandOptions
{
    public const string SectionName = "CameraCommands";

    public string? ConnectionString { get; set; }

    public string? FullyQualifiedNamespace { get; set; }

    public string Queue { get; set; } = "take-picture";
}

public sealed class LocationCommandOptions
{
    public const string SectionName = "LocationCommands";

    public bool Enabled { get; set; }

    public string? ConnectionString { get; set; }

    public string? FullyQualifiedNamespace { get; set; }

    public string Queue { get; set; } = "update-location";
}
