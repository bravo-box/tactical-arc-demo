#!/usr/bin/env bash
# Shared image build helper used by the per-section build scripts.
#
# Usage: build-images.sh --apps-dir <dir> [--registry <acr-login-server>] [--tag <tag>] [--push]
set -euo pipefail

APPS_DIR=""
REGISTRY=""
TAG="0.1.0"
PUSH="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --apps-dir)
    APPS_DIR="$2"
    shift 2
    ;;
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
    sed -n '2,4p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [ -z "${APPS_DIR}" ] || [ ! -d "${APPS_DIR}" ]; then
  echo "--apps-dir must point to an existing directory" >&2
  exit 1
fi

if [ "${PUSH}" = "true" ] && [ -z "${REGISTRY}" ]; then
  echo "--push requires --registry" >&2
  exit 1
fi

for app_dir in "${APPS_DIR%/}"/*/; do
  [ -f "${app_dir}Dockerfile" ] || continue
  app="$(basename "${app_dir}")"
  image="${app}:${TAG}"
  if [ -n "${REGISTRY}" ]; then
    image="${REGISTRY%/}/${image}"
  fi

  echo "Building ${image}"
  docker build -t "${image}" "${app_dir}"

  if [ "${PUSH}" = "true" ]; then
    docker push "${image}"
  fi
done
