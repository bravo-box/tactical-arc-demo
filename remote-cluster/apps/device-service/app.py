"""Serve device information from a local configuration file over MQTT."""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import paho.mqtt.client as mqtt

CONFIG_PATH = Path(os.environ.get("DEVICE_INFO_CONFIG", "/etc/device-service/device.json"))
REQUEST_TOPIC = os.environ.get("DEVICE_INFO_REQUEST_TOPIC", "DeviceInfoRequest")
RESPONSE_TOPIC = os.environ.get("DEVICE_INFO_RESPONSE_TOPIC", "DeviceInfoResponse")
MAX_DEVICE_INFO_JSON_LENGTH = 4096


def load_device_info(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"device information file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"device information file is not valid JSON: {exc}") from exc

    if not isinstance(value, dict) or not value:
        raise ValueError("device information must be a non-empty JSON object")
    encoded = json.dumps(value, separators=(",", ":"), ensure_ascii=True)
    if len(encoded) > MAX_DEVICE_INFO_JSON_LENGTH:
        raise ValueError(
            f"device information must not exceed {MAX_DEVICE_INFO_JSON_LENGTH} encoded characters"
        )
    return value


def build_response(payload: bytes, device_info: dict[str, Any]) -> dict[str, Any] | None:
    try:
        request = json.loads(payload)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    if not isinstance(request, dict) or request.get("type") != "DeviceInfoRequest":
        return None
    correlation_id = request.get("correlationId")
    if not isinstance(correlation_id, str) or not correlation_id.strip():
        return None
    return {
        "type": "DeviceInfoResponse",
        "correlationId": correlation_id,
        "deviceInfo": device_info,
    }


def main() -> None:
    try:
        load_device_info(CONFIG_PATH)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    host = os.environ.get("MQTT_HOST", "localhost")
    port = int(os.environ.get("MQTT_PORT", "1883"))
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="device-service")

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
        mqtt_client.subscribe(REQUEST_TOPIC, qos=1)

    def on_message(
        mqtt_client: mqtt.Client,
        userdata: Any,
        message: mqtt.MQTTMessage,
    ) -> None:
        try:
            device_info = load_device_info(CONFIG_PATH)
        except ValueError as exc:
            print(f"cannot answer DeviceInfoRequest: {exc}", flush=True)
            return
        response = build_response(message.payload, device_info)
        if response is None:
            print("ignored invalid DeviceInfoRequest", flush=True)
            return
        result = mqtt_client.publish(
            RESPONSE_TOPIC,
            json.dumps(response, separators=(",", ":")),
            qos=1,
        )
        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            print(
                f"DeviceInfoResponse publish failed correlationId={response['correlationId']} "
                f"result={result.rc}",
                flush=True,
            )

    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(host, port, keepalive=60)
    client.subscribe(REQUEST_TOPIC, qos=1)
    print(f"device-service requestTopic={REQUEST_TOPIC} responseTopic={RESPONSE_TOPIC}", flush=True)
    client.loop_forever()


if __name__ == "__main__":
    main()
