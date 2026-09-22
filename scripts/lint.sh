#!/usr/bin/env bash
# Lint everything in the repository: shell scripts, Terraform, and Helm charts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

status=0

if command -v shellcheck >/dev/null 2>&1; then
  echo "== shellcheck =="
  # shellcheck disable=SC2312
  find . -path ./.git -prune -o -name '*.sh' -print0 |
    xargs -0 -r shellcheck || status=1
else
  echo "skip: shellcheck not installed"
fi

if command -v terraform >/dev/null 2>&1; then
  echo "== terraform fmt =="
  terraform fmt -check -recursive infra || status=1
else
  echo "skip: terraform not installed"
fi

if command -v helm >/dev/null 2>&1; then
  echo "== helm lint =="
  helm lint cloud-cluster/helm/cloud-cluster || status=1
  helm lint remote-cluster/helm/remote-cluster || status=1
else
  echo "skip: helm not installed"
fi

exit "${status}"
