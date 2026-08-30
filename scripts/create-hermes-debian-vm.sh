#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-hermes-debian-vm.sh [options]

Creates a base Debian stable cloud-image VM on the host's br0 LAN bridge.
The guest uses DHCP, so it receives its own LAN address. Reserve the printed
MAC address in the DHCP server before relying on the address for Caddy.

Options:
  --name NAME          VM name (default: hermes-debian)
  --storage-dir PATH   Disk image directory (default: /srv/appdata/NAME)
  --disk-size GB       Disk size in GiB (default: 100)
  --memory MB          Guest memory in MiB (default: 8192)
  --vcpus COUNT        Guest vCPU count (default: 2)
  --bridge NAME        LAN bridge interface (default: br0)
  --mac ADDRESS        Guest MAC address (default: 52:54:00:12:01:42)
  --ssh-pubkey PATH    SSH public key to install for matt
  --recreate           Destroy and replace an existing VM with this name
  -h, --help           Show this help
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

NAME="hermes-debian"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORAGE_DIR=""
DISK_SIZE_GB=100
MEMORY_MB=8192
VCPUS=2
BRIDGE="br0"
MAC_ADDRESS="52:54:00:12:01:42"
INVOKING_USER="${SUDO_USER:-$USER}"
INVOKING_HOME="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"
SSH_PUBKEY_PATH="${SCRIPT_DIR}/../keys/matt.pub"
RECREATE=0
DEBIAN_IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"

while (($# > 0)); do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --storage-dir) STORAGE_DIR="$2"; shift 2 ;;
    --disk-size) DISK_SIZE_GB="$2"; shift 2 ;;
    --memory) MEMORY_MB="$2"; shift 2 ;;
    --vcpus) VCPUS="$2"; shift 2 ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    --mac) MAC_ADDRESS="$2"; shift 2 ;;
    --ssh-pubkey) SSH_PUBKEY_PATH="$2"; shift 2 ;;
    --recreate) RECREATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$STORAGE_DIR" ]]; then
  STORAGE_DIR="/srv/appdata/${NAME}"
fi

for command in cloud-localds curl qemu-img sha512sum virt-install virsh; do
  require_cmd "$command"
done

if [[ ! -r "$SSH_PUBKEY_PATH" ]]; then
  echo "SSH public key not found: $SSH_PUBKEY_PATH" >&2
  exit 1
fi

if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  echo "LAN bridge does not exist: $BRIDGE" >&2
  exit 1
fi

if ((RECREATE)); then
  if [[ "$STORAGE_DIR" != /srv/appdata/* || "$STORAGE_DIR" == "/srv/appdata/" ]]; then
    echo "Refusing to remove storage outside a named /srv/appdata directory: $STORAGE_DIR" >&2
    exit 1
  fi
  if virsh dominfo "$NAME" >/dev/null 2>&1; then
    if [[ "$(virsh domstate "$NAME")" != "shut off" ]]; then
      virsh destroy "$NAME"
    fi
    virsh undefine "$NAME" --nvram || virsh undefine "$NAME"
  fi
  rm -rf "$STORAGE_DIR"
elif virsh dominfo "$NAME" >/dev/null 2>&1; then
  echo "VM already exists: $NAME (use --recreate to replace it)." >&2
  exit 1
fi

install -d -m 0750 "$STORAGE_DIR"

backing_image="$STORAGE_DIR/debian-13-genericcloud-amd64.qcow2"
checksum_file="$STORAGE_DIR/SHA512SUMS"
system_disk="$STORAGE_DIR/${NAME}-system.qcow2"
seed_image="$STORAGE_DIR/${NAME}-seed.iso"
user_data="$STORAGE_DIR/user-data"
meta_data="$STORAGE_DIR/meta-data"

if [[ ! -f "$backing_image" ]]; then
  curl --fail --location --retry 3 --output "$backing_image" "$DEBIAN_IMAGE_URL"
fi

curl --fail --location --retry 3 --output "$checksum_file" "${DEBIAN_IMAGE_URL%/*}/SHA512SUMS"
(
  cd "$STORAGE_DIR"
  grep ' debian-13-genericcloud-amd64.qcow2$' "$checksum_file" | sha512sum --check --status
)

ssh_pubkey="$(<"$SSH_PUBKEY_PATH")"
cat >"$user_data" <<EOF
#cloud-config
users:
  - default
  - name: matt
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_pubkey}
ssh_pwauth: false
disable_root: true
EOF

cat >"$meta_data" <<EOF
instance-id: ${NAME}
local-hostname: ${NAME}
EOF

cloud-localds "$seed_image" "$user_data" "$meta_data"
qemu-img create -f qcow2 -F qcow2 -b "$backing_image" "$system_disk" "${DISK_SIZE_GB}G" >/dev/null

virt-install \
  --name "$NAME" \
  --memory "$MEMORY_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --boot uefi \
  --os-variant debian13 \
  --disk "path=${system_disk},format=qcow2,bus=virtio" \
  --disk "path=${seed_image},device=cdrom" \
  --network "bridge=${BRIDGE},model=virtio,mac=${MAC_ADDRESS}" \
  --graphics none \
  --console pty,target_type=serial \
  --rng /dev/urandom \
  --import \
  --noautoconsole

cat <<EOF

Debian VM created: ${NAME}
Storage: ${STORAGE_DIR}
Resources: ${VCPUS} vCPU, ${MEMORY_MB} MiB RAM, ${DISK_SIZE_GB} GiB sparse disk
DHCP reservation MAC: ${MAC_ADDRESS}

Reserve that MAC in Omada, then find the assigned 10.12.1.x address and log in:
  ssh matt@<guest-ip>
EOF
