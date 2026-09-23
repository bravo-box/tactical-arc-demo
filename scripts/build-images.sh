#!/usr/bin/env bash
# Shared image build helper used by the per-section build scripts.
#
# Usage: build-images.sh --apps-dir <dir> [--registry <acr>] [--tag <tag>] [--platform <platforms>] [--push]
set -euo pipefail

APPS_DIR=""
REGISTRY=""
TAG="0.1.0"
PUSH="false"
PLATFORMS=""

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
  --platform)
    PLATFORMS="$2"
    shift 2
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

  if [ -n "${PLATFORMS}" ]; then
    build_args=(--platform "${PLATFORMS}" --tag "${image}")
    if [ "${PUSH}" = "true" ]; then
      build_args+=(--push)
    elif [[ "${PLATFORMS}" == *,* ]]; then
      echo "A multi-platform build must use --push." >&2
      exit 1
    else
      build_args+=(--load)
    fi
    echo "Building ${image} for ${PLATFORMS}"
    docker buildx build "${build_args[@]}" "${app_dir}"
  else
    echo "Building ${image}"
    docker build -t "${image}" "${app_dir}"
    if [ "${PUSH}" = "true" ]; then
      docker push "${image}"
    fi
  fi
done
