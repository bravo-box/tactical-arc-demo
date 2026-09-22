#!/usr/bin/env bash
# Verify that the dev container provides all tooling required by this repo.
#
# Usage: verify-tools.sh [--check-ssh]
#   --check-ssh  also test SSH git authentication against github.com (needs network).
set -euo pipefail

CHECK_SSH="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
  --check-ssh)
    CHECK_SSH="true"
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

REQUIRED_TOOLS=(git ssh docker kubectl helm az terraform packer)
missing=0

for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "${tool}" >/dev/null 2>&1; then
    printf 'ok      %-10s %s\n' "${tool}" "$(command -v "${tool}")"
  else
    printf 'MISSING %-10s\n' "${tool}"
    missing=1
  fi
done

if [ "${CHECK_SSH}" = "true" ]; then
  ssh_output="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  if echo "${ssh_output}" | grep -q "successfully authenticated"; then
    echo "ok      ssh git authentication to github.com"
  else
    echo "warn    ssh git authentication to github.com not available"
  fi
fi

exit "${missing}"
