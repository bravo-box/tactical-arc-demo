"""
Tactical ARC Demo - Cloud API Service

This Flask application serves as the cloud-side API for the Tactical ARC Demo,
deployed on Azure Kubernetes Service (AKS) in Azure Government cloud.
It provides endpoints for managing edge devices (Jetson Nano) via Azure Arc.
"""

import os
import logging
from flask import Flask, jsonify, request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
ARC_RESOURCE_GROUP = os.environ.get("ARC_RESOURCE_GROUP", "tactical-arc-rg")
ARC_CLUSTER_NAME = os.environ.get("ARC_CLUSTER_NAME", "tactical-arc-cluster")
AZURE_ENVIRONMENT = os.environ.get("AZURE_ENVIRONMENT", "AzureUSGovernment")


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "service": "cloud-api"}), 200


@app.route("/api/v1/devices", methods=["GET"])
def list_devices():
    """List all registered edge devices."""
    logger.info("Listing registered edge devices")
    # Placeholder: In production, query Arc-enabled Kubernetes resources
    devices = [
        {
            "id": "jetson-nano-001",
            "name": "Jetson Nano 001",
            "status": "connected",
            "arc_enabled": True,
            "location": "edge-site-1",
        }
    ]
    return jsonify({"devices": devices, "count": len(devices)}), 200


@app.route("/api/v1/devices/<device_id>", methods=["GET"])
def get_device(device_id):
    """Get details for a specific edge device."""
    logger.info("Fetching device details for: %s", device_id)
    device = {
        "id": device_id,
        "name": f"Device {device_id}",
        "status": "connected",
        "arc_enabled": True,
        "arc_resource_group": ARC_RESOURCE_GROUP,
        "arc_cluster": ARC_CLUSTER_NAME,
    }
    return jsonify(device), 200


@app.route("/api/v1/devices/<device_id>/command", methods=["POST"])
def send_command(device_id):
    """Send a command to an edge device via Arc."""
    data = request.get_json()
    if not data or "command" not in data:
        return jsonify({"error": "Missing 'command' in request body"}), 400

    command = data["command"]
    logger.info("Sending command '%s' to device %s", command, device_id)
    # Placeholder: In production, dispatch via Arc GitOps or direct cluster access
    return jsonify({
        "device_id": device_id,
        "command": command,
        "status": "queued",
        "message": "Command queued for delivery via Azure Arc",
    }), 202


@app.route("/api/v1/status", methods=["GET"])
def service_status():
    """Return service and environment status."""
    return jsonify({
        "service": "cloud-api",
        "version": "1.0.0",
        "environment": AZURE_ENVIRONMENT,
        "arc_resource_group": ARC_RESOURCE_GROUP,
        "arc_cluster": ARC_CLUSTER_NAME,
    }), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
    logger.info("Starting Cloud API on port %d", port)
    app.run(host="0.0.0.0", port=port, debug=debug)
