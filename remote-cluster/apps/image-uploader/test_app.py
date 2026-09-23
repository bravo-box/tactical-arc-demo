from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

import app
from app import BreakerState, ConnectivityCircuitBreaker


class FakeDeviceInfoClient:
    def request(self) -> dict[str, str]:
        return {"deviceId": "edge-01", "model": "Jetson Nano"}


class FakeLocationClient:
    def request(self) -> dict[str, float]:
        return {"latitude": 47.61, "longitude": -122.33}


class FakeContainer:
    url = "https://example.test/device-images"

    def upload_blob(self, name: str, stream: Any, **kwargs: Any) -> None:
        self.name = name
        self.contents = stream.read()
        self.metadata = kwargs["metadata"]


class FakeBlobService:
    def __init__(self) -> None:
        self.container = FakeContainer()

    def get_container_client(self, name: str) -> FakeContainer:
        return self.container


class FakeSender:
    def __enter__(self) -> "FakeSender":
        return self

    def __exit__(self, *args: Any) -> None:
        return None

    def send_messages(self, message: Any) -> None:
        self.message = message


class FakeServiceBus:
    def __init__(self) -> None:
        self.sender = FakeSender()

    def get_topic_sender(self, topic: str) -> FakeSender:
        return self.sender


class ConnectivityCircuitBreakerTests(unittest.TestCase):
    def test_opens_after_five_failures(self) -> None:
        breaker = ConnectivityCircuitBreaker()
        for second in range(4):
            breaker.record(False, second)
            self.assertEqual(breaker.state, BreakerState.CLOSED)

        breaker.record(False, 4)

        self.assertEqual(breaker.state, BreakerState.OPEN)
        self.assertFalse(breaker.should_probe(63))

    def test_half_open_after_one_minute_and_closes_on_success(self) -> None:
        breaker = ConnectivityCircuitBreaker()
        for second in range(5):
            breaker.record(False, second)

        self.assertTrue(breaker.should_probe(64))
        self.assertEqual(breaker.state, BreakerState.HALF_OPEN)
        self.assertEqual(breaker.probe_interval, 1)

        breaker.record(True, 65)

        self.assertEqual(breaker.state, BreakerState.CLOSED)
        self.assertEqual(breaker.probe_interval, 5)
        self.assertEqual(breaker.failures, 0)

    def test_half_open_failure_keeps_probing_every_second(self) -> None:
        breaker = ConnectivityCircuitBreaker(state=BreakerState.HALF_OPEN, failures=5)
        breaker.record(False, 70)

        self.assertEqual(breaker.state, BreakerState.HALF_OPEN)
        self.assertEqual(breaker.probe_interval, 1)


class ImageUploaderTests(unittest.TestCase):
    def test_upload_adds_current_device_info_to_blob_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "image-1.jpg"
            image.write_bytes(b"jpeg")
            manifest = image.with_suffix(".json")
            manifest.write_text(
                json.dumps(
                    {
                        "type": "SendImage",
                        "id": "image-1",
                        "deviceId": "edge-01",
                        "hostname": "edge-host",
                        "architecture": "arm64",
                        "capturedAt": "2026-09-23T12:00:00+00:00",
                        "fileName": image.name,
                        "localPath": str(image),
                        "contentType": "image/jpeg",
                        "width": 640,
                        "height": 480,
                        "correlationId": "11a3524e-86b3-4428-9f9a-abf51136f1ad",
                    }
                ),
                encoding="utf-8",
            )
            blob_service = FakeBlobService()
            service_bus = FakeServiceBus()
            uploader = app.ImageUploader(
                {
                    "storageContainer": "device-images",
                    "imageUploadTopic": "image-upload",
                },
                blob_service,
                service_bus,
                FakeDeviceInfoClient(),
                FakeLocationClient(),
            )

            uploader.upload(manifest)

            self.assertEqual(
                json.loads(blob_service.container.metadata["deviceinfo"]),
                {"deviceId": "edge-01", "model": "Jetson Nano"},
            )
            self.assertEqual(
                json.loads(str(service_bus.sender.message))["deviceInfo"],
                {"deviceId": "edge-01", "model": "Jetson Nano"},
            )
            self.assertEqual(
                json.loads(str(service_bus.sender.message))["location"],
                {"latitude": 47.61, "longitude": -122.33},
            )
            self.assertEqual(blob_service.container.metadata["latitude"], "47.61")
            self.assertEqual(blob_service.container.metadata["longitude"], "-122.33")
            self.assertFalse(image.exists())
            self.assertFalse(manifest.exists())


if __name__ == "__main__":
    unittest.main()
