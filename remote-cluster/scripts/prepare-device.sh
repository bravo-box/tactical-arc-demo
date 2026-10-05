#!/usr/bin/env bash
# First-boot hardening for a Raspberry Pi or Jetson Nano edge device:
# package upgrade, hostname, SSH, and the cgroup kernel parameters K3s needs.
#
# Run this on the device itself:
#   sudo ./prepare-device.sh --hostname edge-01 [options]
set -euo pipefail

TARGET_HOSTNAME=""
SKIP_UPGRADE="false"
SKIP_SSH="false"
SKIP_REBOOT="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --hostname)
    TARGET_HOSTNAME="$2"
    shift 2
    ;;
  --skip-upgrade)
    SKIP_UPGRADE="true"
    shift
    ;;
  --skip-ssh)
    SKIP_SSH="true"
    shift
    ;;
  --skip-reboot)
    SKIP_REBOOT="true"
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

NEEDS_REBOOT="false"

if [ "${SKIP_UPGRADE}" != "true" ]; then
  echo "Updating and upgrading packages..."
  apt-get update
  apt-get full-upgrade -y
fi

if [ -n "${TARGET_HOSTNAME}" ]; then
  current_hostname="$(hostnamectl --static status 2>/dev/null || hostname)"
  if [ "${current_hostname}" != "${TARGET_HOSTNAME}" ]; then
    echo "Setting hostname to ${TARGET_HOSTNAME}..."
    hostnamectl set-hostname "${TARGET_HOSTNAME}"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
      sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${TARGET_HOSTNAME}/" /etc/hosts
    else
      printf '127.0.1.1\t%s\n' "${TARGET_HOSTNAME}" >>/etc/hosts
    fi
  fi
fi

if [ "${SKIP_SSH}" != "true" ]; then
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^ssh\.service'; then
    echo "Ensuring SSH is enabled..."
    systemctl enable --now ssh
  elif command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^sshd\.service'; then
    systemctl enable --now sshd
  fi
fi

# Raspberry Pi only: K3s requires cgroup memory accounting, which Raspberry Pi
# OS does not enable by default. Jetson/JetPack kernels already enable it.
CMDLINE_FILE=""
for candidate in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
  if [ -f "${candidate}" ]; then
    CMDLINE_FILE="${candidate}"
    break
  fi
done

if [ -n "${CMDLINE_FILE}" ]; then
  if ! grep -q 'cgroup_memory=1' "${CMDLINE_FILE}" || ! grep -q 'cgroup_enable=memory' "${CMDLINE_FILE}"; then
    echo "Enabling cgroup memory accounting in ${CMDLINE_FILE}..."
    cp -a "${CMDLINE_FILE}" "${CMDLINE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    line="$(cat "${CMDLINE_FILE}")"
    for token in cgroup_memory=1 cgroup_enable=memory; do
      case " ${line} " in
      *" ${token} "*) ;;
      *) line="${line} ${token}" ;;
      esac
    done
    printf '%s' "${line}" >"${CMDLINE_FILE}"
    NEEDS_REBOOT="true"
  else
    echo "cgroup memory accounting already enabled in ${CMDLINE_FILE}."
  fi
fi

echo "Device preparation complete."
if [ "${NEEDS_REBOOT}" = "true" ]; then
  if [ "${SKIP_REBOOT}" = "true" ]; then
    echo "A reboot is required to apply cgroup changes; rerun without --skip-reboot or reboot manually." >&2
  else
    echo "Rebooting to apply cgroup changes..."
    reboot
  fi
fi
