#!/usr/bin/env bash
# repo-scripts/build.sh
# Build Docker images for the Tactical ARC Demo.
#
# Usage: build.sh [--target cloud|local|all] [--push] [--tag <tag>]
#   --target  Which app to build: cloud, local, or all (default: all)
#   --push    Push images to ACR after building
#   --tag     Image tag (default: latest)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
TARGET="all"
PUSH=false
TAG="latest"
ACR_NAME="${ACR_NAME:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --push)   PUSH=true;   shift   ;;
    --tag)    TAG="$2";    shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

build_image() {
  local name="$1"
  local context_dir="$2"
  local image_tag="${name}:${TAG}"

  log_info "Building image: ${image_tag}"
  docker build -t "${image_tag}" "${context_dir}"
  log_info "Built: ${image_tag}"

  if [[ "${PUSH}" == "true" ]]; then
    if [[ -z "${ACR_NAME}" ]]; then
      log_error "ACR_NAME environment variable is required for --push"
      exit 1
    fi
    local acr_tag="${ACR_NAME}.azurecr.us/${image_tag}"
    log_info "Tagging and pushing: ${acr_tag}"
    docker tag "${image_tag}" "${acr_tag}"
    docker push "${acr_tag}"
    log_info "Pushed: ${acr_tag}"
  fi
}

echo "================================================"
echo " Tactical ARC Demo - Docker Build"
echo "================================================"
log_info "Target: ${TARGET} | Tag: ${TAG} | Push: ${PUSH}"
echo ""

case "${TARGET}" in
  cloud)
    build_image "cloud-api" "${REPO_ROOT}/cloud-app/api"
    ;;
  local)
    build_image "local-agent" "${REPO_ROOT}/local-app/agent"
    ;;
  all)
    build_image "cloud-api"   "${REPO_ROOT}/cloud-app/api"
    build_image "local-agent" "${REPO_ROOT}/local-app/agent"
    ;;
  *)
    log_error "Unknown target: ${TARGET}. Use cloud, local, or all."
    exit 1
    ;;
esac

echo ""
log_info "Build complete!"
