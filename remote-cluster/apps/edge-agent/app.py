"""Edge agent for the remote cluster.

Collects a simple system reading and forwards it to the cloud telemetry API.
"""
from __future__ import annotations

import json
import os
import socket
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

TELEMETRY_URL = os.environ.get("TELEMETRY_URL", "http://telemetry-api:8080/telemetry")
DEVICE_ID = os.environ.get("DEVICE_ID", socket.gethostname())
INTERVAL_SECONDS = int(os.environ.get("INTERVAL_SECONDS", "30"))
REQUEST_TIMEOUT = int(os.environ.get("REQUEST_TIMEOUT", "10"))


def build_reading() -> dict:
    load_1m, load_5m, load_15m = os.getloadavg()
    return {
        "deviceId": DEVICE_ID,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "load": {"1m": load_1m, "5m": load_5m, "15m": load_15m},
    }


def send_reading(reading: dict) -> None:
    request = urllib.request.Request(  # noqa: S310 - scheme validated in main()
        TELEMETRY_URL,
        data=json.dumps(reading).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:  # noqa: S310
        print(f"sent reading, status={response.status}", flush=True)


def main() -> None:
    if not TELEMETRY_URL.startswith(("http://", "https://")):
        raise SystemExit("TELEMETRY_URL must be an http(s) URL")

    print(f"edge-agent reporting {DEVICE_ID} to {TELEMETRY_URL}", flush=True)
    while True:
        try:
            send_reading(build_reading())
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            print(f"failed to send reading: {exc}", flush=True)
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
