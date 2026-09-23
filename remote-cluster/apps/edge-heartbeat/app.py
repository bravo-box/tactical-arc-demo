"""Publish device heartbeats to an Azure Service Bus topic."""
from __future__ import annotations

import json
import os
import platform
import socket
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.servicebus.exceptions import ServiceBusError

CONFIG_PATH = Path(os.environ.get("EDGE_HEARTBEAT_CONFIG", "/etc/edge-heartbeat/config.json"))
CONNECTION_STRING_ENV = "SERVICEBUS_CONNECTION_STRING"


def load_config(path: Path) -> dict[str, Any]:
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"configuration file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"configuration file is not valid JSON: {exc}") from exc

    interval = config.get("heartbeatIntervalSeconds", 5)
    if not isinstance(interval, (int, float)) or isinstance(interval, bool) or interval <= 0:
        raise ValueError("heartbeatIntervalSeconds must be a positive number")

    topic = config.get("serviceBusTopic")
    if not isinstance(topic, str) or not topic.strip():
        raise ValueError("serviceBusTopic must be a non-empty string")

    device_id = config.get("deviceId") or socket.gethostname()
    if not isinstance(device_id, str) or not device_id.strip():
        raise ValueError("deviceId must be a non-empty string")

    return {
        "deviceId": device_id.strip(),
        "heartbeatIntervalSeconds": float(interval),
        "serviceBusTopic": topic.strip(),
    }


def build_heartbeat(device_id: str) -> dict[str, Any]:
    return {
        "id": str(uuid.uuid4()),
        "type": "edge-heartbeat",
        "deviceId": device_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "hostname": socket.gethostname(),
        "architecture": platform.machine(),
    }


def namespace_connection_string(connection_string: str) -> str:
    parts = [
        part
        for part in connection_string.strip().split(";")
        if part and not part.lower().startswith("entitypath=")
    ]
    return ";".join(parts)


def main() -> None:
    try:
        config = load_config(CONFIG_PATH)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    connection_string = os.environ.get(CONNECTION_STRING_ENV, "").strip()
    if not connection_string:
        raise SystemExit(f"{CONNECTION_STRING_ENV} is required")

    client = ServiceBusClient.from_connection_string(
        namespace_connection_string(connection_string),
        logging_enable=False,
    )
    topic = config["serviceBusTopic"]
    interval = config["heartbeatIntervalSeconds"]
    device_id = config["deviceId"]
    print(
        f"edge-heartbeat device={device_id} topic={topic} interval={interval:g}s",
        flush=True,
    )

    with client, client.get_topic_sender(topic_name=topic) as sender:
        while True:
            heartbeat = build_heartbeat(device_id)
            message = ServiceBusMessage(
                json.dumps(heartbeat, separators=(",", ":")),
                content_type="application/json",
                message_id=heartbeat["id"],
                subject="heartbeat",
                application_properties={"deviceId": device_id},
            )
            try:
                sender.send_messages(message)
                print(
                    f"heartbeat sent id={heartbeat['id']} timestamp={heartbeat['timestamp']}",
                    flush=True,
                )
            except ServiceBusError as exc:
                print(f"heartbeat send failed: {exc}", flush=True)
            time.sleep(interval)


if __name__ == "__main__":
    main()
