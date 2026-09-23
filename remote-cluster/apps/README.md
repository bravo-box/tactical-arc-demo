# remote-cluster/apps

Containerized applications that run at the edge. Each subdirectory contains the
app source code and its `Dockerfile`.

- `edge-heartbeat/` – publishes a configurable heartbeat to an Azure Service Bus topic.
- `device-service/` – serves host-mounted device information over correlated local MQTT requests.
- `camera-capture/` – consumes `TakePicture`, captures an attached V4L2 camera, persists the JPEG, and publishes `SendImage` over local MQTT.
- `image-uploader/` – drains persisted images to Azure Blob Storage, adding current device information via MQTT, and publishes `ImageUpload`.
