#!/usr/bin/env bash
# Build (and optionally push) the edge container images.
#
# Usage: build-images.sh [--registry <acr>] [--tag <tag>] [--platform <platforms>] [--push]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/../../scripts/build-images.sh" --apps-dir "${SCRIPT_DIR}/../apps" "$@"
