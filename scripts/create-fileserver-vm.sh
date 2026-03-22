#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-fileserver-vm.sh [options]

Builds a bootable QCOW2 from the `nixos-fileserver-vm` flake config, then
creates and imports a libvirt/KVM VM with:
  - 1 writable qcow2 system disk backed by the flake-built image
  - 3 ext4-formatted raw data disks
  - 1 ext4-formatted raw parity disk

The data and parity disks are pre-labeled to match
`hosts/nixos-fileserver-vm/storage.nix`:
  fs-disk1, fs-disk2, fs-disk3, fs-parity

This is a fully unattended test setup: no installer ISO and no manual
`nixos-install` step inside the guest. The script prompts for a temporary
password for the `matt` user and injects it only into the VM image build.

Options:
  --name NAME          VM name (default: nixos-fileserver-vm-test)
  --flake PATH         Flake path or URI (default: repo root via path:)
  --host HOST          Flake host attr (default: nixos-fileserver-vm)
  --storage-dir PATH   Disk image directory (default: /var/lib/libvirt/images/NAME)
  --system-size GB     System disk size in GiB (default: 40)
  --data-size GB       Size of each data disk in GiB (default: 20)
  --parity-size GB     Parity disk size in GiB (default: 20)
  --memory MB          VM memory in MiB (default: 8192)
  --vcpus COUNT        Number of vCPUs (default: 4)
  --network NAME       Libvirt network name (default: default)
  --connect URI        Libvirt URI (default: qemu:///system)
  --recreate           Destroy and recreate an existing VM with the same name
  --no-autoconsole     Do not automatically open the VM console
  -h, --help           Show this help

Example:
  scripts/create-fileserver-vm.sh \
    --name nixos-fileserver-vm-test \
    --recreate
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

NAME="nixos-fileserver-vm-test"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_REF="path:${REPO_ROOT}"
HOST_ATTR="nixos-fileserver-vm"
STORAGE_DIR=""
SYSTEM_SIZE_GB=40
DATA_SIZE_GB=20
PARITY_SIZE_GB=20
MEMORY_MB=8192
VCPUS=4
NETWORK_NAME="default"
CONNECT_URI="qemu:///system"
RECREATE=0
AUTO_CONSOLE=1

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
    --data-size)
      DATA_SIZE_GB="$2"
      shift 2
      ;;
    --parity-size)
      PARITY_SIZE_GB="$2"
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
require_cmd mkfs.ext4
require_cmd nix
require_cmd grep
require_cmd head

SYSTEM_DISK="${STORAGE_DIR}/${NAME}-system.qcow2"
DATA_DISK_1="${STORAGE_DIR}/${NAME}-disk1.img"
DATA_DISK_2="${STORAGE_DIR}/${NAME}-disk2.img"
DATA_DISK_3="${STORAGE_DIR}/${NAME}-disk3.img"
PARITY_DISK="${STORAGE_DIR}/${NAME}-parity.img"
BACKING_IMAGE=""
VM_LOGIN_USER="matt"
VM_LOGIN_PASSWORD=""

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

create_labeled_ext4_disk() {
  local path="$1"
  local size_gb="$2"
  local label="$3"

  truncate -s "${size_gb}G" "$path"
  mkfs.ext4 -F -L "$label" "$path" >/dev/null
}

prompt_for_password() {
  local first
  local second

  while true; do
    read -r -s -p "Temporary password for ${VM_LOGIN_USER}: " first
    echo
    read -r -s -p "Confirm password: " second
    echo

    if [[ -z "$first" ]]; then
      echo "Password cannot be empty." >&2
      continue
    fi

    if [[ "$first" != "$second" ]]; then
      echo "Passwords did not match. Try again." >&2
      continue
    fi

    VM_LOGIN_PASSWORD="$first"
    break
  done
}

build_vm_image() {
  local vm_out
  local run_script

  vm_out="$(
    FLAKE_URI="$FLAKE_REF" \
    HOST_NAME="$HOST_ATTR" \
    NIXOS_VM_PASSWORD="$VM_LOGIN_PASSWORD" \
      nix build \
        --impure \
        --expr '
          let
            flake = builtins.getFlake (builtins.getEnv "FLAKE_URI");
            host = builtins.getEnv "HOST_NAME";
            password = builtins.getEnv "NIXOS_VM_PASSWORD";
            config = builtins.getAttr host flake.nixosConfigurations;
          in
            (config.extendModules {
              modules = [
                ({ ... }: {
                  users.users.matt.initialPassword = password;
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

if ((RECREATE)); then
  cleanup_existing_vm
  rm -rf "$STORAGE_DIR"
elif virsh --connect "$CONNECT_URI" dominfo "$NAME" >/dev/null 2>&1; then
  echo "VM already exists: $NAME" >&2
  echo "Re-run with --recreate to replace it." >&2
  exit 1
fi

mkdir -p "$STORAGE_DIR"

prompt_for_password
build_vm_image

qemu-img create -f qcow2 -b "$BACKING_IMAGE" -F qcow2 "$SYSTEM_DISK" "${SYSTEM_SIZE_GB}G" >/dev/null
create_labeled_ext4_disk "$DATA_DISK_1" "$DATA_SIZE_GB" "fs-disk1"
create_labeled_ext4_disk "$DATA_DISK_2" "$DATA_SIZE_GB" "fs-disk2"
create_labeled_ext4_disk "$DATA_DISK_3" "$DATA_SIZE_GB" "fs-disk3"
create_labeled_ext4_disk "$PARITY_DISK" "$PARITY_SIZE_GB" "fs-parity"

virt_install_args=(
  --connect "$CONNECT_URI"
  --name "$NAME"
  --memory "$MEMORY_MB"
  --vcpus "$VCPUS"
  --cpu host-passthrough
  --boot uefi
  --os-variant detect=on,name=linux2022
  --disk "path=${SYSTEM_DISK},format=qcow2,bus=virtio"
  --disk "path=${DATA_DISK_1},format=raw,bus=virtio"
  --disk "path=${DATA_DISK_2},format=raw,bus=virtio"
  --disk "path=${DATA_DISK_3},format=raw,bus=virtio"
  --disk "path=${PARITY_DISK},format=raw,bus=virtio"
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

cat <<EOF

VM created: ${NAME}
Disk directory: ${STORAGE_DIR}
Flake build: ${VM_BUILD_REF}
System backing image: ${BACKING_IMAGE}

Pre-labeled test disks:
  fs-disk1  -> ${DATA_DISK_1}
  fs-disk2  -> ${DATA_DISK_2}
  fs-disk3  -> ${DATA_DISK_3}
  fs-parity -> ${PARITY_DISK}

The VM is ready to boot directly into the flake-built fileserver system.
No installer ISO or in-guest nixos-install step is required.
Login user: ${VM_LOGIN_USER}
EOF
