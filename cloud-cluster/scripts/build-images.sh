#!/usr/bin/env bash
# Build (and optionally push) the cloud cluster container images.
#
# Usage: build-images.sh [--registry <acr-login-server>] [--tag <tag>] [--push]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/../../scripts/build-images.sh" --apps-dir "${SCRIPT_DIR}/../apps" "$@"
