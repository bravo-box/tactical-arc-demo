"""Capture camera images in response to Azure Service Bus commands."""
from __future__ import annotations

import json
import os
import platform
import socket
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import paho.mqtt.client as mqtt
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

CONFIG_PATH = Path(os.environ.get("CAMERA_CONFIG", "/etc/camera-capture/config.json"))
SERVICEBUS_CONNECTION_STRING = "SERVICEBUS_CONNECTION_STRING"


def load_config(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"configuration file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"configuration file is not valid JSON: {exc}") from exc

    required_strings = ("serviceBusQueue", "mqttHost", "mqttTopic", "imageDirectory")
    for key in required_strings:
        if not isinstance(value.get(key), str) or not value[key].strip():
            raise ValueError(f"{key} must be a non-empty string")

    device_id = value.get("deviceId") or socket.gethostname()
    camera_index = value.get("cameraIndex", 0)
    if not isinstance(camera_index, int) or isinstance(camera_index, bool) or camera_index < 0:
        raise ValueError("cameraIndex must be a non-negative integer")

    return {
        "deviceId": device_id,
        "cameraIndex": camera_index,
        "serviceBusQueue": value["serviceBusQueue"].strip(),
        "serviceBusFullyQualifiedNamespace": value.get(
            "serviceBusFullyQualifiedNamespace", ""
        ).strip(),
        "mqttHost": os.environ.get("MQTT_HOST", value["mqttHost"]).strip(),
        "mqttPort": int(value.get("mqttPort", 1883)),
        "mqttTopic": value["mqttTopic"].strip(),
        "imageDirectory": value["imageDirectory"].strip(),
    }


def namespace_connection_string(connection_string: str) -> str:
    return ";".join(
        part
        for part in connection_string.strip().split(";")
        if part and not part.lower().startswith("entitypath=")
    )


def parse_take_picture(body: str) -> dict[str, Any] | None:
    try:
        event = json.loads(body)
    except json.JSONDecodeError:
        return None
    if not isinstance(event, dict):
        return None
    command = event.get("type") or event.get("command")
    return event if command == "TakePicture" else None


def capture_image(camera_index: int, target: Path) -> tuple[int, int]:
    camera = cv2.VideoCapture(camera_index)
    try:
        if not camera.isOpened():
            raise RuntimeError(f"camera {camera_index} could not be opened")
        ok, frame = camera.read()
        if not ok or frame is None:
            raise RuntimeError(f"camera {camera_index} did not return an image")
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_suffix(".tmp.jpg")
        if not cv2.imwrite(str(temporary), frame):
            raise RuntimeError(f"could not write image to {temporary}")
        temporary.replace(target)
        height, width = frame.shape[:2]
        return width, height
    finally:
        camera.release()


def build_metadata(
    device_id: str,
    image_id: str,
    image_path: Path,
    width: int,
    height: int,
    command: dict[str, Any],
) -> dict[str, Any]:
    return {
        "type": "SendImage",
        "id": image_id,
        "deviceId": device_id,
        "hostname": socket.gethostname(),
        "architecture": platform.machine(),
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "fileName": image_path.name,
        "localPath": str(image_path),
        "contentType": "image/jpeg",
        "width": width,
        "height": height,
        "commandId": command.get("id"),
    }


def handle_command(config: dict[str, Any], publisher: mqtt.Client, command: dict[str, Any]) -> dict[str, Any]:
    image_id = str(uuid.uuid4())
    target = Path(config["imageDirectory"]) / f"{image_id}.jpg"
    width, height = capture_image(config["cameraIndex"], target)
    metadata = build_metadata(config["deviceId"], image_id, target, width, height, command)
    manifest = target.with_suffix(".json")
    manifest.write_text(json.dumps(metadata, separators=(",", ":")), encoding="utf-8")
    publish = publisher.publish(
        config["mqttTopic"],
        json.dumps(metadata, separators=(",", ":")),
        qos=1,
    )
    publish.wait_for_publish(timeout=10)
    if publish.rc != mqtt.MQTT_ERR_SUCCESS:
        raise RuntimeError(f"MQTT publish failed with result {publish.rc}")
    return metadata


def main() -> None:
    try:
        config = load_config(CONFIG_PATH)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    connection_string = os.environ.get(SERVICEBUS_CONNECTION_STRING, "").strip()
    fully_qualified_namespace = config["serviceBusFullyQualifiedNamespace"]
    if connection_string:
        service_bus = ServiceBusClient.from_connection_string(
            namespace_connection_string(connection_string),
            logging_enable=False,
        )
    elif fully_qualified_namespace:
        service_bus = ServiceBusClient(
            fully_qualified_namespace,
            DefaultAzureCredential(),
            logging_enable=False,
        )
    else:
        raise SystemExit(
            f"{SERVICEBUS_CONNECTION_STRING} or serviceBusFullyQualifiedNamespace is required"
        )

    publisher = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"camera-{config['deviceId']}")
    publisher.connect(config["mqttHost"], config["mqttPort"], keepalive=60)
    publisher.loop_start()
    print(f"camera-capture device={config['deviceId']} queue={config['serviceBusQueue']}", flush=True)

    try:
        with service_bus, service_bus.get_queue_receiver(
            queue_name=config["serviceBusQueue"],
            max_wait_time=5,
        ) as receiver:
            while True:
                for message in receiver.receive_messages(max_message_count=1, max_wait_time=5):
                    command = parse_take_picture(str(message))
                    if command is None:
                        print("dead-lettering unsupported camera command", flush=True)
                        receiver.dead_letter_message(message, reason="UnsupportedCommand")
                        continue
                    try:
                        metadata = handle_command(config, publisher, command)
                    except Exception as exc:
                        print(f"capture failed: {exc}", flush=True)
                        receiver.abandon_message(message)
                    else:
                        receiver.complete_message(message)
                        print(f"captured image id={metadata['id']}", flush=True)
    finally:
        publisher.disconnect()
        publisher.loop_stop()


if __name__ == "__main__":
    main()
