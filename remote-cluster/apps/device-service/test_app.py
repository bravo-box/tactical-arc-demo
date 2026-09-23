from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import app


class DeviceServiceTests(unittest.TestCase):
    def test_load_device_info_reads_json_object(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "device.json"
            path.write_text(
                json.dumps({"deviceId": "edge-01", "model": "Jetson Nano"}),
                encoding="utf-8",
            )

            result = app.load_device_info(path)

        self.assertEqual(result["deviceId"], "edge-01")
        self.assertEqual(result["model"], "Jetson Nano")

    def test_load_device_info_rejects_empty_object(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "device.json"
            path.write_text("{}", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "non-empty JSON object"):
                app.load_device_info(path)

    def test_build_response_preserves_correlation_and_device_info(self) -> None:
        response = app.build_response(
            b'{"type":"DeviceInfoRequest","correlationId":"request-1"}',
            {"deviceId": "edge-01"},
        )

        self.assertEqual(
            response,
            {
                "type": "DeviceInfoResponse",
                "correlationId": "request-1",
                "deviceInfo": {"deviceId": "edge-01"},
            },
        )

    def test_build_response_rejects_invalid_request(self) -> None:
        self.assertIsNone(app.build_response(b"not-json", {"deviceId": "edge-01"}))
        self.assertIsNone(
            app.build_response(b'{"type":"Other","correlationId":"request-1"}', {})
        )
        self.assertIsNone(app.build_response(b'{"type":"DeviceInfoRequest"}', {}))


if __name__ == "__main__":
    unittest.main()
