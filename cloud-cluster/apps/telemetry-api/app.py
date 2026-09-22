"""Minimal telemetry API for the cloud cluster.

Accepts telemetry posted by the edge agent and exposes the most recent
readings plus a health endpoint used by Kubernetes probes.
"""
from __future__ import annotations

import json
import os
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_READINGS = int(os.environ.get("MAX_READINGS", "100"))
MAX_BODY_BYTES = int(os.environ.get("MAX_BODY_BYTES", str(64 * 1024)))
PORT = int(os.environ.get("PORT", "8080"))

READINGS: deque[dict] = deque(maxlen=MAX_READINGS)


class TelemetryHandler(BaseHTTPRequestHandler):
    server_version = "telemetry-api/1.0"

    def _respond(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path in ("/healthz", "/readyz"):
            self._respond(200, {"status": "ok"})
        elif self.path == "/telemetry":
            self._respond(200, {"count": len(READINGS), "readings": list(READINGS)})
        else:
            self._respond(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path != "/telemetry":
            self._respond(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BODY_BYTES:
            self._respond(413, {"error": "invalid content length"})
            return

        try:
            reading = json.loads(self.rfile.read(length))
        except json.JSONDecodeError:
            self._respond(400, {"error": "invalid json"})
            return

        if not isinstance(reading, dict):
            self._respond(400, {"error": "expected a json object"})
            return

        READINGS.append(reading)
        self._respond(202, {"accepted": True, "count": len(READINGS)})

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} - {fmt % args}", flush=True)


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), TelemetryHandler)
    print(f"telemetry-api listening on port {PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
