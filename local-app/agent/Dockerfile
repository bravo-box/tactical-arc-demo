FROM nvcr.io/nvidia/l4t-base:r32.7.1

LABEL maintainer="tactical-arc-demo"
LABEL description="Tactical ARC Demo - Local Edge Agent for Jetson Nano"

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application source
COPY src/ .

# Non-root user for security
RUN groupadd --system appgroup && useradd --system --gid appgroup appuser
USER appuser

ENV CLOUD_API_URL="http://cloud-api/api/v1"
ENV DEVICE_ID="jetson-nano-001"
ENV HEARTBEAT_INTERVAL="30"
ENV AZURE_ENVIRONMENT="AzureUSGovernment"

CMD ["python3", "agent.py"]
