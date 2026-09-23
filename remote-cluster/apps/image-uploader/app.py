"""Upload locally captured images when connectivity is available."""
from __future__ import annotations

import json
import os
import queue
import socket
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any, Callable

import paho.mqtt.client as mqtt
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.storage.blob import BlobServiceClient, ContentSettings

CONFIG_PATH = Path(os.environ.get("IMAGE_UPLOADER_CONFIG", "/etc/image-uploader/config.json"))
STORAGE_CONNECTION_STRING = "STORAGE_CONNECTION_STRING"
SERVICEBUS_CONNECTION_STRING = "SERVICEBUS_CONNECTION_STRING"


class BreakerState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half-open"


@dataclass
class ConnectivityCircuitBreaker:
    failure_threshold: int = 5
    reset_seconds: float = 60
    closed_interval_seconds: float = 5
    half_open_interval_seconds: float = 1
    state: BreakerState = BreakerState.CLOSED
    failures: int = 0
    opened_at: float | None = None

    def record(self, connected: bool, now: float) -> None:
        if connected:
            self.state = BreakerState.CLOSED
            self.failures = 0
            self.opened_at = None
            return
        if self.state is BreakerState.HALF_OPEN:
            return
        self.failures += 1
        if self.failures >= self.failure_threshold:
            self.state = BreakerState.OPEN
            self.opened_at = now

    def should_probe(self, now: float) -> bool:
        if self.state is BreakerState.OPEN:
            if self.opened_at is None or now - self.opened_at < self.reset_seconds:
                return False
            self.state = BreakerState.HALF_OPEN
        return True

    @property
    def probe_interval(self) -> float:
        if self.state is BreakerState.CLOSED:
            return self.closed_interval_seconds
        return self.half_open_interval_seconds


def load_config(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"configuration file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"configuration file is not valid JSON: {exc}") from exc
    for key in ("mqttHost", "mqttTopic", "imageDirectory", "storageContainer", "imageUploadTopic"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            raise ValueError(f"{key} must be a non-empty string")
    return {
        "mqttHost": os.environ.get("MQTT_HOST", value["mqttHost"]),
        "mqttPort": int(value.get("mqttPort", 1883)),
        "mqttTopic": value["mqttTopic"],
        "imageDirectory": value["imageDirectory"],
        "storageContainer": value["storageContainer"],
        "storageAccountUrl": value.get("storageAccountUrl", "").strip(),
        "imageUploadTopic": value["imageUploadTopic"],
        "serviceBusFullyQualifiedNamespace": value.get(
            "serviceBusFullyQualifiedNamespace", ""
        ).strip(),
        "connectivityHost": value.get("connectivityHost", "1.1.1.1"),
        "connectivityPort": int(value.get("connectivityPort", 443)),
    }


def namespace_connection_string(connection_string: str) -> str:
    return ";".join(
        part
        for part in connection_string.strip().split(";")
        if part and not part.lower().startswith("entitypath=")
    )


def internet_available(host: str, port: int, timeout: float = 2) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


class ImageUploader:
    def __init__(
        self,
        config: dict[str, Any],
        blob_service: BlobServiceClient,
        service_bus: ServiceBusClient,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.config = config
        self.blob_service = blob_service
        self.service_bus = service_bus
        self.clock = clock
        self.breaker = ConnectivityCircuitBreaker()
        self.pending: queue.Queue[Path] = queue.Queue()
        self._known: set[Path] = set()
        self._known_lock = threading.Lock()

    def enqueue_manifest(self, manifest: Path) -> None:
        with self._known_lock:
            if manifest in self._known:
                return
            self._known.add(manifest)
        self.pending.put(manifest)

    def scan_pending(self) -> None:
        for manifest in Path(self.config["imageDirectory"]).glob("*.json"):
            self.enqueue_manifest(manifest)

    def upload(self, manifest: Path) -> None:
        metadata = json.loads(manifest.read_text(encoding="utf-8"))
        image_path = Path(metadata["localPath"])
        blob_name = f"{metadata['deviceId']}/{metadata['capturedAt'][:10]}/{metadata['fileName']}"
        container = self.blob_service.get_container_client(self.config["storageContainer"])
        with image_path.open("rb") as stream:
            container.upload_blob(
                blob_name,
                stream,
                overwrite=True,
                content_settings=ContentSettings(content_type=metadata["contentType"]),
                metadata={
                    "deviceid": metadata["deviceId"],
                    "capturedat": metadata["capturedAt"],
                    "imageid": metadata["id"],
                    "hostname": metadata["hostname"],
                    "architecture": metadata["architecture"],
                    "width": str(metadata["width"]),
                    "height": str(metadata["height"]),
                    "commandid": str(metadata.get("commandId") or ""),
                },
            )
        uploaded = {
            **metadata,
            "type": "ImageUpload",
            "blobName": blob_name,
            "imageUrl": f"{container.url}/{blob_name}",
            "uploadedAt": datetime.now(timezone.utc).isoformat(),
        }
        with self.service_bus.get_topic_sender(self.config["imageUploadTopic"]) as sender:
            sender.send_messages(
                ServiceBusMessage(
                    json.dumps(uploaded, separators=(",", ":")),
                    content_type="application/json",
                    message_id=metadata["id"],
                    subject="ImageUpload",
                    application_properties={"deviceId": metadata["deviceId"]},
                )
            )
        image_path.unlink(missing_ok=True)
        manifest.unlink(missing_ok=True)
        print(f"uploaded image id={metadata['id']} blob={blob_name}", flush=True)

    def process_pending(self) -> None:
        while True:
            try:
                manifest = self.pending.get_nowait()
            except queue.Empty:
                return
            try:
                if manifest.exists():
                    self.upload(manifest)
            except Exception as exc:
                print(f"upload failed manifest={manifest}: {exc}", flush=True)
                self.pending.put(manifest)
                return
            else:
                with self._known_lock:
                    self._known.discard(manifest)
            finally:
                self.pending.task_done()

    def run(self, stop: threading.Event) -> None:
        next_probe = 0.0
        while not stop.is_set():
            self.scan_pending()
            now = self.clock()
            if now >= next_probe and self.breaker.should_probe(now):
                connected = internet_available(
                    self.config["connectivityHost"],
                    self.config["connectivityPort"],
                )
                previous = self.breaker.state
                self.breaker.record(connected, now)
                if previous is not self.breaker.state:
                    print(f"connectivity circuit {self.breaker.state.value}", flush=True)
                if connected:
                    self.process_pending()
                next_probe = now + self.breaker.probe_interval
            stop.wait(0.25)


def main() -> None:
    try:
        config = load_config(CONFIG_PATH)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    storage = os.environ.get(STORAGE_CONNECTION_STRING, "").strip()
    service_bus_connection = os.environ.get(SERVICEBUS_CONNECTION_STRING, "").strip()
    if storage:
        blob_service = BlobServiceClient.from_connection_string(storage)
    elif config["storageAccountUrl"]:
        blob_service = BlobServiceClient(config["storageAccountUrl"], DefaultAzureCredential())
    else:
        raise SystemExit(f"{STORAGE_CONNECTION_STRING} or storageAccountUrl is required")
    if service_bus_connection:
        service_bus = ServiceBusClient.from_connection_string(
            namespace_connection_string(service_bus_connection),
            logging_enable=False,
        )
    elif config["serviceBusFullyQualifiedNamespace"]:
        service_bus = ServiceBusClient(
            config["serviceBusFullyQualifiedNamespace"],
            DefaultAzureCredential(),
            logging_enable=False,
        )
    else:
        raise SystemExit(
            f"{SERVICEBUS_CONNECTION_STRING} or serviceBusFullyQualifiedNamespace is required"
        )
    uploader = ImageUploader(config, blob_service, service_bus)
    stop = threading.Event()

    def on_message(client: mqtt.Client, userdata: Any, message: mqtt.MQTTMessage) -> None:
        try:
            metadata = json.loads(message.payload)
            if metadata.get("type") == "SendImage":
                uploader.enqueue_manifest(Path(metadata["localPath"]).with_suffix(".json"))
        except (json.JSONDecodeError, KeyError, TypeError) as exc:
            print(f"invalid SendImage event: {exc}", flush=True)

    subscriber = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="image-uploader")
    subscriber.on_message = on_message
    subscriber.connect(config["mqttHost"], config["mqttPort"], keepalive=60)
    subscriber.subscribe(config["mqttTopic"], qos=1)
    subscriber.loop_start()
    print(f"image-uploader topic={config['mqttTopic']}", flush=True)
    try:
        with service_bus:
            uploader.run(stop)
    finally:
        stop.set()
        subscriber.disconnect()
        subscriber.loop_stop()


if __name__ == "__main__":
    main()
