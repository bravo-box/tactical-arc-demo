#!/usr/bin/env bash
# Build (and optionally push) the edge container images.
#
# Usage: build-images.sh [--registry <acr-login-server>] [--tag <tag>] [--push]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="${SCRIPT_DIR}/../apps"

REGISTRY=""
TAG="0.1.0"
PUSH="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --registry)
    REGISTRY="$2"
    shift 2
    ;;
  --tag)
    TAG="$2"
    shift 2
    ;;
  --push)
    PUSH="true"
    shift
    ;;
  -h | --help)
    sed -n '2,5p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

for app_dir in "${APPS_DIR}"/*/; do
  [ -f "${app_dir}Dockerfile" ] || continue
  app="$(basename "${app_dir}")"
  image="${app}:${TAG}"
  if [ -n "${REGISTRY}" ]; then
    image="${REGISTRY%/}/${image}"
  fi

  echo "Building ${image}"
  docker build -t "${image}" "${app_dir}"

  if [ "${PUSH}" = "true" ]; then
    if [ -z "${REGISTRY}" ]; then
      echo "--push requires --registry" >&2
      exit 1
    fi
    docker push "${image}"
  fi
done
