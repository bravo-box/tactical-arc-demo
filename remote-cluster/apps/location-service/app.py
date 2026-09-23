"""Persist and serve device location over MQTT."""
from __future__ import annotations

import json
import math
import os
import threading
import uuid
from pathlib import Path
from typing import Any

import paho.mqtt.client as mqtt
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient

LOCATION_PATH = Path(os.environ.get("LOCATION_FILE", "/var/lib/location/location.json"))
REQUEST_TOPIC = os.environ.get("LOCATION_REQUEST_TOPIC", "RequestLocation")
RESPONSE_TOPIC = os.environ.get("LOCATION_RESPONSE_TOPIC", "ResponseLocation")
UPDATE_REQUEST_TOPIC = os.environ.get(
    "LOCATION_UPDATE_REQUEST_TOPIC", "UpdateLocationRequest"
)
UPDATE_RESPONSE_TOPIC = os.environ.get(
    "LOCATION_UPDATE_RESPONSE_TOPIC", "UpdateLocationResponse"
)
SERVICEBUS_CONNECTION_STRING = "SERVICEBUS_CONNECTION_STRING"


def validate_location(value: Any) -> dict[str, float]:
    if not isinstance(value, dict):
        raise ValueError("location must be a JSON object")
    latitude = value.get("latitude")
    longitude = value.get("longitude")
    if (
        not isinstance(latitude, (int, float))
        or isinstance(latitude, bool)
        or not math.isfinite(latitude)
        or latitude < -90
        or latitude > 90
    ):
        raise ValueError("latitude must be a finite number between -90 and 90")
    if (
        not isinstance(longitude, (int, float))
        or isinstance(longitude, bool)
        or not math.isfinite(longitude)
        or longitude < -180
        or longitude > 180
    ):
        raise ValueError("longitude must be a finite number between -180 and 180")
    return {"latitude": float(latitude), "longitude": float(longitude)}


def load_location(path: Path) -> dict[str, float]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"location file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"location file is not valid JSON: {exc}") from exc
    return validate_location(value)


def save_location(path: Path, location: dict[str, float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(f"{path.suffix}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(
        json.dumps(location, separators=(",", ":")),
        encoding="utf-8",
    )
    temporary.replace(path)


def parse_request(payload: bytes, expected_type: str) -> dict[str, Any] | None:
    try:
        request = json.loads(payload)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    if not isinstance(request, dict) or request.get("type") != expected_type:
        return None
    correlation_id = request.get("correlationId")
    if not isinstance(correlation_id, str) or not correlation_id.strip():
        return None
    return request


def build_location_response(
    payload: bytes, location: dict[str, float]
) -> dict[str, Any] | None:
    request = parse_request(payload, "RequestLocation")
    if request is None:
        return None
    return {
        "type": "ResponseLocation",
        "correlationId": request["correlationId"],
        "location": location,
    }


def apply_update(payload: bytes, path: Path) -> dict[str, Any] | None:
    request = parse_request(payload, "UpdateLocationRequest")
    if request is None:
        return None
    try:
        location = validate_location(request.get("location"))
        save_location(path, location)
    except (OSError, ValueError) as exc:
        return {
            "type": "UpdateLocationResponse",
            "correlationId": request["correlationId"],
            "status": "rejected",
            "error": str(exc),
        }
    return {
        "type": "UpdateLocationResponse",
        "correlationId": request["correlationId"],
        "status": "updated",
        "location": location,
    }


def namespace_connection_string(connection_string: str) -> str:
    return ";".join(
        part
        for part in connection_string.strip().split(";")
        if part and not part.lower().startswith("entitypath=")
    )


def publish_json(client: mqtt.Client, topic: str, payload: dict[str, Any]) -> None:
    result = client.publish(
        topic,
        json.dumps(payload, separators=(",", ":")),
        qos=1,
    )
    if result.rc != mqtt.MQTT_ERR_SUCCESS:
        print(f"MQTT publish failed topic={topic} result={result.rc}", flush=True)


def main() -> None:
    try:
        load_location(LOCATION_PATH)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    host = os.environ.get("MQTT_HOST", "localhost")
    port = int(os.environ.get("MQTT_PORT", "1883"))
    device_id = os.environ.get("DEVICE_ID", "").strip()
    queue_name = os.environ.get("LOCATION_COMMAND_QUEUE", "update-location").strip()
    namespace = os.environ.get("SERVICEBUS_FULLY_QUALIFIED_NAMESPACE", "").strip()
    connection_string = os.environ.get(SERVICEBUS_CONNECTION_STRING, "").strip()
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="location-service")
    connected = threading.Event()

    def on_connect(
        mqtt_client: mqtt.Client,
        userdata: Any,
        flags: mqtt.ConnectFlags,
        reason_code: mqtt.ReasonCode,
        properties: mqtt.Properties | None,
    ) -> None:
        if reason_code.is_failure:
            print(f"MQTT connection failed: {reason_code}", flush=True)
            return
        mqtt_client.subscribe([(REQUEST_TOPIC, 1), (UPDATE_REQUEST_TOPIC, 1)])
        connected.set()

    def on_message(
        mqtt_client: mqtt.Client,
        userdata: Any,
        message: mqtt.MQTTMessage,
    ) -> None:
        if message.topic == REQUEST_TOPIC:
            try:
                location = load_location(LOCATION_PATH)
            except ValueError as exc:
                print(f"cannot answer RequestLocation: {exc}", flush=True)
                return
            response = build_location_response(message.payload, location)
            if response is not None:
                publish_json(mqtt_client, RESPONSE_TOPIC, response)
            return
        response = apply_update(message.payload, LOCATION_PATH)
        if response is not None:
            publish_json(mqtt_client, UPDATE_RESPONSE_TOPIC, response)

    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(host, port, keepalive=60)
    client.subscribe([(REQUEST_TOPIC, 1), (UPDATE_REQUEST_TOPIC, 1)])
    print(
        f"location-service requestTopic={REQUEST_TOPIC} updateTopic={UPDATE_REQUEST_TOPIC}",
        flush=True,
    )

    if not connection_string and not namespace:
        client.loop_forever()
        return
    client.loop_start()
    if not connected.wait(10):
        raise SystemExit("MQTT connection was not established within 10 seconds")
    if not device_id:
        raise SystemExit("DEVICE_ID is required when Service Bus commands are configured")
    if connection_string:
        service_bus = ServiceBusClient.from_connection_string(
            namespace_connection_string(connection_string),
            logging_enable=False,
        )
    else:
        service_bus = ServiceBusClient(
            namespace,
            DefaultAzureCredential(),
            logging_enable=False,
        )
    try:
        with service_bus, service_bus.get_queue_receiver(
            queue_name=queue_name,
            session_id=device_id,
            max_wait_time=5,
        ) as receiver:
            while True:
                for message in receiver.receive_messages(
                    max_message_count=1, max_wait_time=5
                ):
                    request = parse_request(
                        str(message).encode("utf-8"), "UpdateLocationRequest"
                    )
                    if request is None or request.get("deviceId") != device_id:
                        receiver.dead_letter_message(
                            message, reason="InvalidLocationCommand"
                        )
                        continue
                    result = client.publish(
                        UPDATE_REQUEST_TOPIC,
                        json.dumps(request, separators=(",", ":")),
                        qos=1,
                    )
                    result.wait_for_publish(timeout=10)
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        receiver.complete_message(message)
                    else:
                        receiver.abandon_message(message)
    finally:
        client.disconnect()
        client.loop_stop()


if __name__ == "__main__":
    main()
