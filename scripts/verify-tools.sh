#!/usr/bin/env bash
# Verify that the dev container provides all tooling required by this repo.
set -euo pipefail

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

ssh_output="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
if echo "${ssh_output}" | grep -q "successfully authenticated"; then
  echo "ok      ssh git authentication to github.com"
else
  echo "warn    ssh git authentication to github.com not available"
fi

exit "${missing}"
