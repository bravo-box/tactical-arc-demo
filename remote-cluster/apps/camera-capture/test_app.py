from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import app


class CameraCaptureTests(unittest.TestCase):
    def test_load_config_applies_camera_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(
                json.dumps(
                    {
                        "deviceId": "edge-01",
                        "serviceBusQueue": "take-picture",
                        "mqttHost": "mqtt",
                        "mqttTopic": "edge/images/send",
                        "imageDirectory": "/images",
                    }
                ),
                encoding="utf-8",
            )
            config = app.load_config(path)

        self.assertEqual(config["cameraIndex"], 0)
        self.assertEqual(config["mqttPort"], 1883)

    def test_parse_take_picture_accepts_type_or_command(self) -> None:
        correlation_id = "11a3524e-86b3-4428-9f9a-abf51136f1ad"
        self.assertEqual(
            app.parse_take_picture(
                json.dumps(
                    {
                        "type": "TakePicture",
                        "id": correlation_id,
                        "correlationId": correlation_id,
                    }
                )
            )["id"],
            correlation_id,
        )
        self.assertIsNotNone(
            app.parse_take_picture(
                json.dumps(
                    {
                        "command": "TakePicture",
                        "correlationId": correlation_id,
                    }
                )
            )
        )
        self.assertIsNone(app.parse_take_picture('{"type":"Restart"}'))
        self.assertIsNone(app.parse_take_picture("not-json"))

    def test_parse_take_picture_requires_matching_device_and_guid(self) -> None:
        self.assertIsNone(
            app.parse_take_picture(
                '{"type":"TakePicture","deviceId":"edge-02","correlationId":"not-a-guid"}',
                "edge-01",
            )
        )

    def test_build_metadata_describes_image(self) -> None:
        metadata = app.build_metadata(
            "edge-01",
            "image-1",
            Path("/images/image-1.jpg"),
            640,
            480,
            {
                "id": "command-1",
                "correlationId": "11a3524e-86b3-4428-9f9a-abf51136f1ad",
            },
        )

        self.assertEqual(metadata["type"], "SendImage")
        self.assertEqual(metadata["deviceId"], "edge-01")
        self.assertTrue(metadata["hostname"])
        self.assertTrue(metadata["architecture"])
        self.assertEqual(metadata["width"], 640)
        self.assertEqual(metadata["commandId"], "command-1")
        self.assertEqual(
            metadata["correlationId"],
            "11a3524e-86b3-4428-9f9a-abf51136f1ad",
        )


if __name__ == "__main__":
    unittest.main()
