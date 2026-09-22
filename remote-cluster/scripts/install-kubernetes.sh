#!/usr/bin/env bash
# Stand up a single-node Kubernetes (K3s) cluster on an edge device and
# configure Docker so that images can be built locally.
#
# Run this on the edge device itself:
#   sudo ./install-kubernetes.sh [--k3s-version <version>] [--skip-docker]
set -euo pipefail

K3S_VERSION=""
INSTALL_DOCKER="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --k3s-version)
    K3S_VERSION="$2"
    shift 2
    ;;
  --skip-docker)
    INSTALL_DOCKER="false"
    shift
    ;;
  -h | --help)
    sed -n '2,6p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "Docker already installed: $(docker --version)"
  else
    echo "Installing Docker Engine..."
    curl -fsSL https://get.docker.com | sh
  fi

  # Configure the daemon for edge use: bounded log files and live restore so
  # containers keep running across daemon restarts on unreliable links.
  install -d -m 0755 /etc/docker
  cat >/etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
JSON

  systemctl enable docker
  systemctl restart docker

  if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG docker "${SUDO_USER}"
    echo "Added ${SUDO_USER} to the docker group (re-login required)."
  fi
}

install_k3s() {
  if command -v k3s >/dev/null 2>&1; then
    echo "K3s already installed: $(k3s --version | head -n 1)"
    return
  fi

  echo "Installing K3s..."
  if [ -n "${K3S_VERSION}" ]; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - --write-kubeconfig-mode 0640
  else
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 0640
  fi
}

configure_kubeconfig() {
  local target_user="${SUDO_USER:-root}"
  local home_dir
  home_dir="$(getent passwd "${target_user}" | cut -d: -f6)"
  local kube_dir="${home_dir}/.kube"

  install -d -m 0700 -o "${target_user}" "${kube_dir}"
  install -m 0600 -o "${target_user}" /etc/rancher/k3s/k3s.yaml "${kube_dir}/config"
  echo "Wrote kubeconfig to ${kube_dir}/config"
}

if [ "${INSTALL_DOCKER}" = "true" ]; then
  install_docker
fi
install_k3s
configure_kubeconfig

echo "Waiting for the node to become ready..."
k3s kubectl wait --for=condition=Ready node --all --timeout=300s
k3s kubectl get nodes
