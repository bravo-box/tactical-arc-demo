from __future__ import annotations

import json
import threading
import unittest

import paho.mqtt.client as mqtt

from device_info_client import DeviceInfoClient


class FakePublish:
    rc = mqtt.MQTT_ERR_SUCCESS

    def wait_for_publish(self, timeout: float) -> None:
        return None


class FakeMqttClient:
    def __init__(self, device_info_client: DeviceInfoClient) -> None:
        self.device_info_client = device_info_client

    def publish(self, topic: str, payload: str, qos: int) -> FakePublish:
        request = json.loads(payload)
        self.device_info_client._device_info = {"deviceId": "edge-01"}
        self.device_info_client._event.set()
        self.topic = topic
        self.correlation_id = request["correlationId"]
        return FakePublish()


class DeviceInfoClientTests(unittest.TestCase):
    def test_request_publishes_correlated_request_and_returns_device_info(self) -> None:
        client = DeviceInfoClient.__new__(DeviceInfoClient)
        client.timeout_seconds = 1
        client.request_topic = "DeviceInfoRequest"
        client.response_topic = "DeviceInfoResponse"
        client._event = threading.Event()
        client._lock = threading.Lock()
        client._correlation_id = None
        client._device_info = None
        client._client = FakeMqttClient(client)

        device_info = client.request()

        self.assertEqual(device_info, {"deviceId": "edge-01"})
        self.assertEqual(client._client.topic, "DeviceInfoRequest")
        self.assertEqual(client._client.correlation_id, client._correlation_id)


if __name__ == "__main__":
    unittest.main()
