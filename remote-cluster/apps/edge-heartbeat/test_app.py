from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import app


class EdgeHeartbeatTests(unittest.TestCase):
    def test_load_config_reads_device_name_and_health(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(
                json.dumps(
                    {
                        "device-name": "edge-01",
                        "healthStatus": "Green",
                        "heartbeatIntervalSeconds": 5,
                        "serviceBusTopic": "edge-heartbeat",
                    }
                ),
                encoding="utf-8",
            )

            config = app.load_config(path)

        self.assertEqual(config["device-name"], "edge-01")
        self.assertEqual(config["healthStatus"], "Green")
        self.assertEqual(config["heartbeatIntervalSeconds"], 5.0)
        self.assertEqual(config["serviceBusTopic"], "edge-heartbeat")

    def test_load_config_rejects_non_positive_interval(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(
                json.dumps(
                    {
                        "heartbeatIntervalSeconds": 0,
                        "serviceBusTopic": "edge-heartbeat",
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "positive number"):
                app.load_config(path)

    def test_load_config_rejects_unknown_health_status(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(
                json.dumps(
                    {
                        "device-name": "edge-01",
                        "healthStatus": "Unknown",
                        "heartbeatIntervalSeconds": 5,
                        "serviceBusTopic": "edge-heartbeat",
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "Green, Yellow, or Red"):
                app.load_config(path)

    def test_build_heartbeat_includes_device_metadata(self) -> None:
        heartbeat = app.build_heartbeat(
            "edge-01",
            "Green",
            {"model": "Jetson Nano"},
        )

        self.assertEqual(heartbeat["type"], "edge-heartbeat")
        self.assertEqual(heartbeat["device-name"], "edge-01")
        self.assertEqual(heartbeat["healthStatus"], "Green")
        self.assertTrue(heartbeat["ipAddress"])
        self.assertTrue(heartbeat["id"])
        self.assertTrue(heartbeat["timestamp"])
        self.assertEqual(heartbeat["deviceInfo"]["model"], "Jetson Nano")

    def test_namespace_connection_string_removes_entity_path(self) -> None:
        connection_string = (
            "Endpoint=sb://example/;SharedAccessKeyName=sender;"
            "SharedAccessKey=secret;EntityPath=edge-heartbeat"
        )

        result = app.namespace_connection_string(connection_string)

        self.assertNotIn("EntityPath", result)
        self.assertIn("SharedAccessKeyName=sender", result)


if __name__ == "__main__":
    unittest.main()
