#!/usr/bin/env bash
# Post-create setup for the tactical-arc-demo dev container.
# Installs tooling that is not provided by dev container features (Packer)
# and configures SSH so that git operations authenticate with the user's keys.
set -euo pipefail

install_packer() {
  if command -v packer >/dev/null 2>&1; then
    echo "packer already installed: $(packer version)"
    return
  fi

  echo "Installing HashiCorp Packer..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release
  sudo install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg |
    sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  sudo chmod a+r /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
    sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y packer
}

configure_ssh() {
  local ssh_dir="${HOME}/.ssh"
  local mounted_ssh_dir="${HOME}/.ssh-localhost"

  mkdir -p "${ssh_dir}"
  chmod 700 "${ssh_dir}"

  # The host ~/.ssh directory is bind-mounted read-only; copy it so that the
  # keys get container-local permissions that ssh accepts.
  if [ -d "${mounted_ssh_dir}" ]; then
    cp -r "${mounted_ssh_dir}/." "${ssh_dir}/"
    chmod 700 "${ssh_dir}"
    find "${ssh_dir}" -type f -exec chmod 600 {} +
    find "${ssh_dir}" -type f -name '*.pub' -exec chmod 644 {} +
  fi

  # Trust GitHub's host keys so that `git clone git@github.com:...` is not
  # blocked by an interactive host key prompt.
  if ! grep -q "github.com" "${ssh_dir}/known_hosts" 2>/dev/null; then
    ssh-keyscan -t rsa,ecdsa,ed25519 github.com >>"${ssh_dir}/known_hosts" 2>/dev/null || true
    chmod 600 "${ssh_dir}/known_hosts"
  fi

  # Load available private keys into the forwarded/local agent.
  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    eval "$(ssh-agent -s)" >/dev/null
  fi
  for key in "${ssh_dir}"/id_*; do
    [ -f "${key}" ] || continue
    case "${key}" in
    *.pub) continue ;;
    esac
    ssh-add "${key}" >/dev/null 2>&1 || true
  done
}

install_packer
configure_ssh

echo "Dev container ready:"
for tool in git ssh kubectl helm az terraform packer; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo "  - ${tool}: $(command -v "${tool}")"
  else
    echo "  - ${tool}: NOT FOUND"
  fi
done
