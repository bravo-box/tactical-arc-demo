from __future__ import annotations

import json
import threading
import unittest

import paho.mqtt.client as mqtt

from location_client import LocationClient


class FakePublish:
    rc = mqtt.MQTT_ERR_SUCCESS

    def wait_for_publish(self, timeout: float) -> None:
        return None


class FakeMqttClient:
    def __init__(self, location_client: LocationClient) -> None:
        self.location_client = location_client

    def publish(self, topic: str, payload: str, qos: int) -> FakePublish:
        request = json.loads(payload)
        self.location_client._location = {
            "latitude": 47.61,
            "longitude": -122.33,
        }
        self.location_client._event.set()
        self.topic = topic
        self.correlation_id = request["correlationId"]
        return FakePublish()


class LocationClientTests(unittest.TestCase):
    def test_request_publishes_correlated_request_and_returns_location(self) -> None:
        client = LocationClient.__new__(LocationClient)
        client.timeout_seconds = 1
        client.request_topic = "RequestLocation"
        client.response_topic = "ResponseLocation"
        client._event = threading.Event()
        client._lock = threading.Lock()
        client._correlation_id = None
        client._location = None
        client._client = FakeMqttClient(client)

        location = client.request()

        self.assertEqual(
            location,
            {"latitude": 47.61, "longitude": -122.33},
        )
        self.assertEqual(client._client.topic, "RequestLocation")
        self.assertEqual(client._client.correlation_id, client._correlation_id)


if __name__ == "__main__":
    unittest.main()
