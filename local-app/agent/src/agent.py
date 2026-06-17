"""
Tactical ARC Demo - Local Edge Agent

This Python agent runs on a Jetson Nano at the edge, connects to Azure Arc,
and manages local workloads. It communicates with the cloud API for command
dispatch and status reporting.
"""

import os
import time
import logging
import json
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
CLOUD_API_URL = os.environ.get("CLOUD_API_URL", "http://cloud-api/api/v1")
DEVICE_ID = os.environ.get("DEVICE_ID", "jetson-nano-001")
HEARTBEAT_INTERVAL = int(os.environ.get("HEARTBEAT_INTERVAL", "30"))
AZURE_ENVIRONMENT = os.environ.get("AZURE_ENVIRONMENT", "AzureUSGovernment")


def get_system_info() -> dict:
    """Collect system information from the edge device."""
    info = {
        "device_id": DEVICE_ID,
        "azure_environment": AZURE_ENVIRONMENT,
        "hostname": os.uname().nodename,
        "timestamp": time.time(),
    }
    # Attempt to read GPU info on Jetson Nano
    try:
        with open("/sys/devices/platform/host1x/57000000.gpu/devfreq/57000000.gpu/cur_freq") as f:
            info["gpu_freq_hz"] = int(f.read().strip())
    except (FileNotFoundError, PermissionError):
        info["gpu_freq_hz"] = None

    return info


def send_heartbeat(system_info: dict) -> bool:
    """Send a heartbeat to the cloud API."""
    try:
        response = requests.post(
            f"{CLOUD_API_URL}/devices/{DEVICE_ID}/heartbeat",
            json=system_info,
            timeout=10,
        )
        if response.status_code in (200, 202):
            logger.info("Heartbeat sent successfully")
            return True
        logger.warning("Heartbeat returned status %d", response.status_code)
        return False
    except requests.exceptions.ConnectionError:
        logger.warning("Could not reach cloud API at %s", CLOUD_API_URL)
        return False
    except requests.exceptions.Timeout:
        logger.warning("Heartbeat request timed out")
        return False


def poll_commands() -> list:
    """Poll the cloud API for pending commands."""
    try:
        response = requests.get(
            f"{CLOUD_API_URL}/devices/{DEVICE_ID}/commands/pending",
            timeout=10,
        )
        if response.status_code == 200:
            return response.json().get("commands", [])
    except (requests.exceptions.RequestException, json.JSONDecodeError):
        pass
    return []


def execute_command(command: dict) -> None:
    """Execute a command received from the cloud."""
    cmd_type = command.get("type", "unknown")
    cmd_args = command.get("args", {})
    logger.info("Executing command: %s with args: %s", cmd_type, cmd_args)

    if cmd_type == "ping":
        logger.info("Ping received - device is alive")
    elif cmd_type == "restart_service":
        service = cmd_args.get("service", "")
        logger.info("Restart requested for service: %s", service)
        # Placeholder: In production, use systemctl or kubectl
    elif cmd_type == "update_config":
        logger.info("Config update received: %s", cmd_args)
    else:
        logger.warning("Unknown command type: %s", cmd_type)


def run_agent() -> None:
    """Main agent loop."""
    logger.info(
        "Starting edge agent for device '%s' targeting '%s'",
        DEVICE_ID,
        AZURE_ENVIRONMENT,
    )
    logger.info("Cloud API endpoint: %s", CLOUD_API_URL)
    logger.info("Heartbeat interval: %d seconds", HEARTBEAT_INTERVAL)

    while True:
        try:
            system_info = get_system_info()
            send_heartbeat(system_info)
            commands = poll_commands()
            for command in commands:
                execute_command(command)
        except Exception as exc:  # pylint: disable=broad-except
            logger.error("Agent loop error: %s", exc)

        time.sleep(HEARTBEAT_INTERVAL)


if __name__ == "__main__":
    run_agent()
