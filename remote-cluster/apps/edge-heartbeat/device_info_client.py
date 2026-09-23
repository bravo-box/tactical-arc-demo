"""Correlated request/response client for local device information."""
from __future__ import annotations

import json
import threading
import uuid
from typing import Any

import paho.mqtt.client as mqtt


class DeviceInfoClient:
    def __init__(
        self,
        host: str,
        port: int = 1883,
        timeout_seconds: float = 5,
        client_id: str = "device-info-client",
        request_topic: str = "DeviceInfoRequest",
        response_topic: str = "DeviceInfoResponse",
    ) -> None:
        self.timeout_seconds = timeout_seconds
        self.request_topic = request_topic
        self.response_topic = response_topic
        self._event = threading.Event()
        self._lock = threading.Lock()
        self._correlation_id: str | None = None
        self._device_info: dict[str, Any] | None = None
        self._client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
        self._client.on_connect = self._on_connect
        self._client.on_message = self._on_message
        self._client.connect(host, port, keepalive=60)
        self._client.subscribe(response_topic, qos=1)
        self._client.loop_start()

    def _on_connect(
        self,
        client: mqtt.Client,
        userdata: Any,
        flags: mqtt.ConnectFlags,
        reason_code: mqtt.ReasonCode,
        properties: mqtt.Properties | None,
    ) -> None:
        if not reason_code.is_failure:
            client.subscribe(self.response_topic, qos=1)

    def _on_message(
        self,
        client: mqtt.Client,
        userdata: Any,
        message: mqtt.MQTTMessage,
    ) -> None:
        try:
            response = json.loads(message.payload)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return
        if (
            not isinstance(response, dict)
            or response.get("type") != "DeviceInfoResponse"
            or response.get("correlationId") != self._correlation_id
            or not isinstance(response.get("deviceInfo"), dict)
        ):
            return
        self._device_info = response["deviceInfo"]
        self._event.set()

    def request(self) -> dict[str, Any]:
        with self._lock:
            self._event.clear()
            self._device_info = None
            self._correlation_id = str(uuid.uuid4())
            payload = json.dumps(
                {
                    "type": "DeviceInfoRequest",
                    "correlationId": self._correlation_id,
                },
                separators=(",", ":"),
            )
            result = self._client.publish(self.request_topic, payload, qos=1)
            result.wait_for_publish(timeout=self.timeout_seconds)
            if result.rc != mqtt.MQTT_ERR_SUCCESS:
                raise RuntimeError(f"DeviceInfoRequest publish failed with result {result.rc}")
            if not self._event.wait(self.timeout_seconds):
                raise TimeoutError(
                    f"no DeviceInfoResponse received within {self.timeout_seconds:g} seconds"
                )
            if self._device_info is None:
                raise RuntimeError("DeviceInfoResponse did not contain device information")
            return self._device_info.copy()

    def close(self) -> None:
        self._client.disconnect()
        self._client.loop_stop()
