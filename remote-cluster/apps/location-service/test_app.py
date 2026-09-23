from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import app


class LocationServiceTests(unittest.TestCase):
    def test_load_and_save_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "location.json"
            app.save_location(path, {"latitude": 47.61, "longitude": -122.33})

            location = app.load_location(path)

        self.assertEqual(location, {"latitude": 47.61, "longitude": -122.33})

    def test_validate_location_rejects_out_of_range_values(self) -> None:
        with self.assertRaisesRegex(ValueError, "between -90 and 90"):
            app.validate_location({"latitude": 91, "longitude": 0})
        with self.assertRaisesRegex(ValueError, "between -180 and 180"):
            app.validate_location({"latitude": 0, "longitude": -181})

    def test_load_location_rejects_invalid_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "location.json"
            path.write_text("not-json", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "not valid JSON"):
                app.load_location(path)

    def test_build_location_response_preserves_correlation(self) -> None:
        response = app.build_location_response(
            b'{"type":"RequestLocation","correlationId":"request-1"}',
            {"latitude": 47.61, "longitude": -122.33},
        )

        self.assertEqual(
            response,
            {
                "type": "ResponseLocation",
                "correlationId": "request-1",
                "location": {"latitude": 47.61, "longitude": -122.33},
            },
        )

    def test_apply_update_persists_and_confirms_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "location.json"
            response = app.apply_update(
                json.dumps(
                    {
                        "type": "UpdateLocationRequest",
                        "correlationId": "request-2",
                        "location": {"latitude": 40.71, "longitude": -74.0},
                    }
                ).encode(),
                path,
            )

            saved = app.load_location(path)

        self.assertEqual(response["status"], "updated")
        self.assertEqual(saved, {"latitude": 40.71, "longitude": -74.0})

    def test_apply_update_rejects_invalid_location_without_writing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "location.json"
            response = app.apply_update(
                b'{"type":"UpdateLocationRequest","correlationId":"request-3",'
                b'"location":{"latitude":"north","longitude":0}}',
                path,
            )

            self.assertEqual(response["status"], "rejected")
            self.assertFalse(path.exists())

    def test_requests_require_type_and_correlation_id(self) -> None:
        self.assertIsNone(
            app.build_location_response(
                b'{"type":"Other","correlationId":"request-4"}',
                {"latitude": 0, "longitude": 0},
            )
        )
        self.assertIsNone(
            app.apply_update(
                b'{"type":"UpdateLocationRequest","location":{"latitude":0,"longitude":0}}',
                Path("unused.json"),
            )
        )


if __name__ == "__main__":
    unittest.main()
