#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-minipc-vm.sh [options]

Builds a bootable QCOW2 from the `nixos-minipc-vm` flake config, then creates
and imports a libvirt/KVM VM with a single writable qcow2 system disk.

This is a fully unattended test setup: no installer ISO and no manual
`nixos-install` step inside the guest. The script injects your SSH public key
into the `matt` account for first-boot provisioning and installs a persistent
agenix identity into the guest after SSH becomes available.

Options:
  --name NAME          VM name (default: nixos-minipc-vm-test)
  --flake PATH         Flake path or URI (default: repo root via path:)
  --host HOST          Flake host attr (default: nixos-minipc-vm)
  --storage-dir PATH   Disk image directory (default: /var/lib/libvirt/images/NAME)
  --system-size GB     System disk size in GiB (default: 40)
  --memory MB          VM memory in MiB (default: 8192)
  --vcpus COUNT        Number of vCPUs (default: 4)
  --ssh-pubkey PATH    SSH public key to inject for post-boot provisioning
                       (default: ~/.ssh/id_ed25519.pub when present)
  --ssh-key PATH       SSH private key to use for post-boot provisioning
                       (default: derived from --ssh-pubkey)
  --agenix-key PATH    Persistent agenix identity to install in the guest
                       (default: ~/.local/share/nixos-minipc-vm/agenix/identity)
  --network NAME       Libvirt network name (default: default)
  --connect URI        Libvirt URI (default: qemu:///system)
  --recreate           Destroy and recreate an existing VM with the same name
  --no-autoconsole     Do not automatically open the VM console
  -h, --help           Show this help

Example:
  scripts/create-minipc-vm.sh \
    --name nixos-minipc-vm-test \
    --recreate
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

NAME="nixos-minipc-vm-test"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_REF="path:${REPO_ROOT}"
HOST_ATTR="nixos-minipc-vm"
STORAGE_DIR=""
INVOKING_USER="${SUDO_USER:-$USER}"
INVOKING_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"
SYSTEM_SIZE_GB=40
MEMORY_MB=8192
VCPUS=4
SSH_PUBKEY_PATH="${INVOKING_HOME}/.ssh/id_ed25519.pub"
SSH_PRIVATE_KEY_PATH=""
AGENIX_IDENTITY_PATH="${INVOKING_HOME}/.local/share/nixos-minipc-vm/agenix/identity"
NETWORK_NAME="default"
CONNECT_URI="qemu:///system"
RECREATE=0
AUTO_CONSOLE=1
SSH_PUBKEY_CONTENT=""

while (($# > 0)); do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --flake)
      FLAKE_REF="$2"
      shift 2
      ;;
    --host)
      HOST_ATTR="$2"
      shift 2
      ;;
    --storage-dir)
      STORAGE_DIR="$2"
      shift 2
      ;;
    --system-size)
      SYSTEM_SIZE_GB="$2"
      shift 2
      ;;
    --memory)
      MEMORY_MB="$2"
      shift 2
      ;;
    --vcpus)
      VCPUS="$2"
      shift 2
      ;;
    --ssh-pubkey)
      SSH_PUBKEY_PATH="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_PRIVATE_KEY_PATH="$2"
      shift 2
      ;;
    --agenix-key)
      AGENIX_IDENTITY_PATH="$2"
      shift 2
      ;;
    --network)
      NETWORK_NAME="$2"
      shift 2
      ;;
    --connect)
      CONNECT_URI="$2"
      shift 2
      ;;
    --recreate)
      RECREATE=1
      shift
      ;;
    --no-autoconsole)
      AUTO_CONSOLE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$STORAGE_DIR" ]]; then
  STORAGE_DIR="/var/lib/libvirt/images/${NAME}"
fi

VM_BUILD_REF="${FLAKE_REF}#nixosConfigurations.${HOST_ATTR}.config.system.build.vmWithBootLoader"

require_cmd virt-install
require_cmd virsh
require_cmd qemu-img
require_cmd nix
require_cmd grep
require_cmd head
require_cmd awk
require_cmd cut
require_cmd getent
require_cmd scp
require_cmd ssh

SYSTEM_DISK="${STORAGE_DIR}/${NAME}-system.qcow2"
BACKING_IMAGE=""
VM_LOGIN_USER="matt"

if [[ -z "$INVOKING_HOME" ]]; then
  echo "Could not determine home directory for invoking user: $INVOKING_USER" >&2
  exit 1
fi

read_ssh_pubkey() {
  if [[ ! -f "$SSH_PUBKEY_PATH" ]]; then
    echo "SSH public key not found: $SSH_PUBKEY_PATH" >&2
    echo "Set --ssh-pubkey PATH to a key that can log into the VM for agenix provisioning." >&2
    exit 1
  fi

  SSH_PUBKEY_CONTENT="$(<"$SSH_PUBKEY_PATH")"

  if [[ -z "$SSH_PRIVATE_KEY_PATH" ]]; then
    SSH_PRIVATE_KEY_PATH="${SSH_PUBKEY_PATH%.pub}"
  fi

  if [[ ! -f "$SSH_PRIVATE_KEY_PATH" ]]; then
    echo "SSH private key not found: $SSH_PRIVATE_KEY_PATH" >&2
    echo "Set --ssh-key PATH to the private key matching $SSH_PUBKEY_PATH." >&2
    exit 1
  fi
}

ensure_agenix_identity() {
  if [[ -f "$AGENIX_IDENTITY_PATH" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$AGENIX_IDENTITY_PATH")"
  nix shell nixpkgs#age -c age-keygen -o "$AGENIX_IDENTITY_PATH" >/dev/null
  chmod 600 "$AGENIX_IDENTITY_PATH"
}

cleanup_existing_vm() {
  if ! virsh --connect "$CONNECT_URI" dominfo "$NAME" >/dev/null 2>&1; then
    return 0
  fi

  state="$(virsh --connect "$CONNECT_URI" domstate "$NAME" 2>/dev/null || true)"
  if [[ "$state" == "running" || "$state" == "paused" || "$state" == "in shutdown" ]]; then
    virsh --connect "$CONNECT_URI" destroy "$NAME" >/dev/null
  fi

  virsh --connect "$CONNECT_URI" undefine "$NAME" --nvram >/dev/null 2>&1 \
    || virsh --connect "$CONNECT_URI" undefine "$NAME" >/dev/null
}

build_vm_image() {
  local vm_out
  local run_script

  vm_out="$(
    FLAKE_URI="$FLAKE_REF" \
    HOST_NAME="$HOST_ATTR" \
    NIXOS_VM_SSH_PUBKEY="$SSH_PUBKEY_CONTENT" \
      nix build \
        --impure \
        --expr '
          let
            flake = builtins.getFlake (builtins.getEnv "FLAKE_URI");
            host = builtins.getEnv "HOST_NAME";
            sshPubKey = builtins.getEnv "NIXOS_VM_SSH_PUBKEY";
            config = builtins.getAttr host flake.nixosConfigurations;
          in
            (config.extendModules {
              modules = [
                ({ lib, ... }: {
                  users.users.matt.openssh.authorizedKeys.keys =
                    lib.optional (sshPubKey != "") sshPubKey;
                  security.sudo.wheelNeedsPassword = lib.mkForce false;
                })
              ];
            }).config.system.build.vmWithBootLoader
        ' \
        --no-link \
        --print-out-paths
  )"
  run_script="${vm_out}/bin/run-${HOST_ATTR}-vm"

  if [[ ! -x "$run_script" ]]; then
    echo "Could not find VM run script in build output: $run_script" >&2
    exit 1
  fi

  BACKING_IMAGE="$(grep -Eo '/nix/store/[^" ]+/nixos\.qcow2' "$run_script" | head -n1 || true)"
  if [[ -z "$BACKING_IMAGE" || ! -f "$BACKING_IMAGE" ]]; then
    echo "Could not determine backing QCOW2 from $run_script" >&2
    exit 1
  fi
}

wait_for_vm_ip() {
  local ip=""

  echo "Waiting for VM IP address..." >&2
  for _ in $(seq 1 60); do
    ip="$(
      virsh --connect "$CONNECT_URI" domifaddr "$NAME" --source lease 2>/dev/null \
        | awk '/ipv4/ { sub(/\/.*/, "", $4); print $4; exit }'
    )"

    if [[ -n "$ip" ]]; then
      echo "VM IP address: $ip" >&2
      printf '%s\n' "$ip"
      return 0
    fi

    sleep 2
  done

  return 1
}

wait_for_ssh() {
  local ip="$1"
  local attempt=0
  local max_attempts=150

  echo "Waiting for SSH on ${ip}..."
  for attempt in $(seq 1 "$max_attempts"); do
    if ssh \
      -i "$SSH_PRIVATE_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=5 \
      "${VM_LOGIN_USER}@${ip}" true >/dev/null 2>&1; then
      echo "SSH is ready on ${ip}"
      return 0
    fi

    if (( attempt % 10 == 0 )); then
      echo "SSH not ready yet on ${ip} (${attempt}/${max_attempts})..."
    fi

    sleep 2
  done

  echo "SSH did not become ready on ${ip} after $((max_attempts * 2)) seconds." >&2
  return 1
}

install_agenix_identity() {
  local ip="$1"

  echo "Installing agenix identity in guest..."
  scp \
    -i "$SSH_PRIVATE_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$AGENIX_IDENTITY_PATH" \
    "${VM_LOGIN_USER}@${ip}:/tmp/agenix-identity" >/dev/null

  ssh \
    -i "$SSH_PRIVATE_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${VM_LOGIN_USER}@${ip}" \
    "sudo -n install -d -m 0700 /var/lib/agenix && sudo -n install -m 0400 /tmp/agenix-identity /var/lib/agenix/identity && sudo -n chown root:root /var/lib/agenix/identity && rm -f /tmp/agenix-identity && sudo -n /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
  echo "Agenix identity installed."
}

if ((RECREATE)); then
  cleanup_existing_vm
  rm -rf "$STORAGE_DIR"
elif virsh --connect "$CONNECT_URI" dominfo "$NAME" >/dev/null 2>&1; then
  echo "VM already exists: $NAME" >&2
  echo "Re-run with --recreate to replace it." >&2
  exit 1
fi

mkdir -p "$STORAGE_DIR"

read_ssh_pubkey
ensure_agenix_identity
build_vm_image

qemu-img create -f qcow2 -b "$BACKING_IMAGE" -F qcow2 "$SYSTEM_DISK" "${SYSTEM_SIZE_GB}G" >/dev/null

virt_install_args=(
  --connect "$CONNECT_URI"
  --name "$NAME"
  --memory "$MEMORY_MB"
  --vcpus "$VCPUS"
  --cpu host-passthrough
  --boot uefi
  --os-variant detect=on,name=linux2022
  --disk "path=${SYSTEM_DISK},format=qcow2,bus=virtio"
  --network "network=${NETWORK_NAME},model=virtio"
  --graphics spice
  --video virtio
  --channel spicevmc
  --rng /dev/urandom
  --wait 0
  --import
)

if ((AUTO_CONSOLE == 0)); then
  virt_install_args+=(--noautoconsole)
fi

virt-install "${virt_install_args[@]}"

VM_IP="$(wait_for_vm_ip)"

if [[ -z "$VM_IP" ]]; then
  echo "Failed to determine VM IP address for agenix provisioning." >&2
  exit 1
fi

if ! wait_for_ssh "$VM_IP"; then
  echo "VM became reachable on the network, but SSH did not become ready." >&2
  exit 1
fi

install_agenix_identity "$VM_IP"

cat <<EOF

VM created: ${NAME}
Disk directory: ${STORAGE_DIR}
Flake build: ${VM_BUILD_REF}
System backing image: ${BACKING_IMAGE}

System disk:
  ${SYSTEM_DISK}

The VM is ready to boot directly into the flake-built mini PC test system.
No installer ISO or in-guest nixos-install step is required.
Login user: ${VM_LOGIN_USER}
Persistent agenix identity: ${AGENIX_IDENTITY_PATH}
EOF
