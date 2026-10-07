#!/usr/bin/env bash
# Connect this edge device to the Azure VNet over an IKEv2 site-to-site
# (strongSwan) tunnel to the Terraform VPN Gateway, and pin the private ACR
# endpoint names in /etc/hosts so registry pulls resolve to private IPs.
#
# Run this on the edge device:
#   sudo ./configure-vpn.sh --gateway-address <ip> --remote-cidr <cidr> \
#     --local-cidr <cidr> --psk-file <path> [--host <fqdn>=<ip>] [options]
set -euo pipefail

CONNECTION_NAME="azure-edge"
GATEWAY_ADDRESS=""
LOCAL_ID=""
PSK_FILE=""
REMOTE_CIDRS=()
LOCAL_CIDRS=()
HOST_ENTRIES=()
# Azure VPN Gateway default IKEv2 policy accepts these proposals.
IKE_PROPOSALS="aes256-sha256-modp2048,aes256-sha256-modp1024,aes256-sha1-modp1024"
ESP_PROPOSALS="aes256gcm16,aes256-sha256,aes256-sha1"
SKIP_INSTALL="false"
SKIP_CHECK="false"

HOSTS_FILE="/etc/hosts"
HOSTS_BEGIN="# BEGIN tactical-arc-demo vpn hosts"
HOSTS_END="# END tactical-arc-demo vpn hosts"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --name)
    CONNECTION_NAME="$2"
    shift 2
    ;;
  --gateway-address)
    GATEWAY_ADDRESS="$2"
    shift 2
    ;;
  --local-id)
    LOCAL_ID="$2"
    shift 2
    ;;
  --psk-file)
    PSK_FILE="$2"
    shift 2
    ;;
  --remote-cidr)
    REMOTE_CIDRS+=("$2")
    shift 2
    ;;
  --local-cidr)
    LOCAL_CIDRS+=("$2")
    shift 2
    ;;
  --host)
    HOST_ENTRIES+=("$2")
    shift 2
    ;;
  --ike-proposals)
    IKE_PROPOSALS="$2"
    shift 2
    ;;
  --esp-proposals)
    ESP_PROPOSALS="$2"
    shift 2
    ;;
  --skip-install)
    SKIP_INSTALL="true"
    shift
    ;;
  --skip-check)
    SKIP_CHECK="true"
    shift
    ;;
  -h | --help)
    sed -n '2,8p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

ipv4_re='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
cidr_re='^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'
fqdn_re='^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi
if ! [[ "${CONNECTION_NAME}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "--name may only contain letters, digits, '-' and '_'" >&2
  exit 1
fi
if ! [[ "${GATEWAY_ADDRESS}" =~ ${ipv4_re} ]]; then
  echo "--gateway-address must be the VPN Gateway public IPv4 address" >&2
  exit 1
fi
if [ -n "${LOCAL_ID}" ] && ! [[ "${LOCAL_ID}" =~ ${ipv4_re} ]]; then
  echo "--local-id must be an IPv4 address (the edge public IP)" >&2
  exit 1
fi
if [ -z "${PSK_FILE}" ] || [ ! -r "${PSK_FILE}" ] || [ ! -s "${PSK_FILE}" ]; then
  echo "--psk-file must be a readable, non-empty file" >&2
  exit 1
fi
if [ "${#REMOTE_CIDRS[@]}" -eq 0 ] || [ "${#LOCAL_CIDRS[@]}" -eq 0 ]; then
  echo "At least one --remote-cidr and one --local-cidr are required" >&2
  exit 1
fi
for cidr in "${REMOTE_CIDRS[@]}" "${LOCAL_CIDRS[@]}"; do
  if ! [[ "${cidr}" =~ ${cidr_re} ]]; then
    echo "Invalid CIDR: ${cidr}" >&2
    exit 1
  fi
done
for entry in "${HOST_ENTRIES[@]}"; do
  host="${entry%%=*}"
  ip="${entry#*=}"
  if [ "${host}" = "${entry}" ] || ! [[ "${host}" =~ ${fqdn_re} ]] || ! [[ "${ip}" =~ ${ipv4_re} ]]; then
    echo "--host must be <fqdn>=<ipv4>: ${entry}" >&2
    exit 1
  fi
done

if [ "${SKIP_INSTALL}" != "true" ] && ! command -v swanctl >/dev/null 2>&1; then
  echo "Installing strongSwan (swanctl/charon-systemd)..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y strongswan-swanctl charon-systemd
fi
if ! command -v swanctl >/dev/null 2>&1; then
  echo "Required command not found: swanctl" >&2
  exit 1
fi

SERVICE=""
for unit in strongswan strongswan-swanctl; do
  if systemctl list-unit-files "${unit}.service" 2>/dev/null | grep -q "^${unit}\.service"; then
    SERVICE="${unit}"
    break
  fi
done
if [ -z "${SERVICE}" ]; then
  echo "Could not find the strongSwan charon-systemd service unit." >&2
  exit 1
fi

join_by_comma() {
  local IFS=","
  echo "$*"
}

# Hex-encode the pre-shared key so arbitrary characters never need escaping.
psk_hex="$(tr -d '\r\n' <"${PSK_FILE}" | od -An -v -tx1 | tr -d ' \n')"
local_id_line=""
if [ -n "${LOCAL_ID}" ]; then
  local_id_line="id = ${LOCAL_ID}"
fi

CONFIG_FILE="/etc/swanctl/conf.d/${CONNECTION_NAME}.conf"
echo "Writing ${CONFIG_FILE}..."
install -d -m 0750 /etc/swanctl/conf.d
umask 077
cat >"${CONFIG_FILE}" <<EOF
# Managed by tactical-arc-demo configure-vpn.sh
connections {
  ${CONNECTION_NAME} {
    version = 2
    remote_addrs = ${GATEWAY_ADDRESS}
    proposals = ${IKE_PROPOSALS}
    rekey_time = 25200s
    dpd_delay = 30s
    mobike = no
    local {
      auth = psk
      ${local_id_line}
    }
    remote {
      auth = psk
      id = ${GATEWAY_ADDRESS}
    }
    children {
      ${CONNECTION_NAME} {
        local_ts = $(join_by_comma "${LOCAL_CIDRS[@]}")
        remote_ts = $(join_by_comma "${REMOTE_CIDRS[@]}")
        esp_proposals = ${ESP_PROPOSALS}
        rekey_time = 10800s
        start_action = start
        dpd_action = restart
        close_action = start
      }
    }
  }
}

secrets {
  ike-${CONNECTION_NAME} {
    id-gateway = ${GATEWAY_ADDRESS}
    secret = 0x${psk_hex}
  }
}
EOF
chmod 0600 "${CONFIG_FILE}"

echo "Starting ${SERVICE} and loading the tunnel configuration..."
systemctl enable "${SERVICE}"
systemctl restart "${SERVICE}"
swanctl --load-all
# start_action=start makes charon initiate the tunnel itself; wait for it.
established="false"
for _ in $(seq 1 30); do
  if swanctl --list-sas --ike "${CONNECTION_NAME}" 2>/dev/null | grep -q ESTABLISHED; then
    established="true"
    break
  fi
  sleep 2
done
swanctl --list-sas --ike "${CONNECTION_NAME}" || true
if [ "${established}" != "true" ]; then
  echo "Tunnel is not established yet; charon will keep retrying." >&2
fi

if [ "${#HOST_ENTRIES[@]}" -gt 0 ]; then
  echo "Pinning private endpoint names in ${HOSTS_FILE}..."
  cp -a "${HOSTS_FILE}" "${HOSTS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  hosts_tmp="$(mktemp)"
  sed "/^${HOSTS_BEGIN}\$/,/^${HOSTS_END}\$/d" "${HOSTS_FILE}" >"${hosts_tmp}"
  {
    echo "${HOSTS_BEGIN}"
    for entry in "${HOST_ENTRIES[@]}"; do
      printf '%s\t%s\n' "${entry#*=}" "${entry%%=*}"
    done
    echo "${HOSTS_END}"
  } >>"${hosts_tmp}"
  cat "${hosts_tmp}" >"${HOSTS_FILE}"
  rm -f "${hosts_tmp}"
fi

if [ "${SKIP_CHECK}" != "true" ] && [ "${#HOST_ENTRIES[@]}" -gt 0 ]; then
  echo "Checking HTTPS reachability of private endpoints over the tunnel..."
  failed="false"
  for entry in "${HOST_ENTRIES[@]}"; do
    host="${entry%%=*}"
    ip="${entry#*=}"
    if timeout 10 bash -c "exec 3<>/dev/tcp/${ip}/443" 2>/dev/null; then
      echo "  OK   ${host} (${ip}:443)"
    else
      echo "  FAIL ${host} (${ip}:443)" >&2
      failed="true"
    fi
  done
  if [ "${failed}" = "true" ]; then
    echo "One or more endpoints are unreachable. Check 'swanctl --list-sas'," >&2
    echo "'journalctl -u ${SERVICE}', and that the Azure local network gateway" >&2
    echo "address/prefixes match this device." >&2
    exit 1
  fi
fi

echo "VPN configuration complete."
