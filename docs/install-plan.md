# NixOS Installation Guide: Gaming & Development

This guide follows a chronological path to a fully optimized NixOS system using **Btrfs**, **Flakes**, and **Home Manager**.

---

## Phase 1: Disk Partitioning & Btrfs Layout
*Run these commands from the NixOS Live Environment terminal.*

### 1. Identify Your Disk (Safety First)
Disk names like `/dev/nvme3n1` can change between reboots. It is **strongly recommended** to use stable identifiers in `/dev/disk/by-id/`.

Run this to find your disk's stable ID (look for `CT1000P3SSD8`):
```bash
ls -l /dev/disk/by-id/ | grep nvme
```

For this guide, we will set a variable to make the following commands copy-paste safe. Replace the path below with your specific ID:
```bash
# Your stable disk ID
export DISK="/dev/disk/by-id/nvme-CT1000P3SSD8_2323E6DF96AF"
```

### 2. Partitioning
```bash
# Create GPT partition table
gdisk $DISK
# Command: o (New partition table)
# Command: n (New partition) -> 1 (Partition number) -> Default start -> +512M -> Type: ef00 (EFI)
# Command: n (New partition) -> 2 (Partition number) -> Default start -> Default end -> Type: 8300 (Linux)
# Command: w (Write and exit)
```

### 3. Format
```bash
mkfs.fat -F 32 -n boot ${DISK}-part1
mkfs.btrfs -L nixos ${DISK}-part2
```

### 4. Create Subvolumes
```bash
mount ${DISK}-part2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt
```

### 5. Mount with Performance Options
```bash
# Mount root
mount -o compress=zstd,noatime,discard=async,subvol=@ ${DISK}-part2 /mnt

# Mount dependencies
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o compress=zstd,noatime,discard=async,subvol=@home ${DISK}-part2 /mnt/home
mount -o compress=zstd,noatime,discard=async,noacl,subvol=@nix ${DISK}-part2 /mnt/nix
mount -o compress=zstd,noatime,discard=async,subvol=@log ${DISK}-part2 /mnt/var/log
mount ${DISK}-part1 /mnt/boot
```

---

## Phase 2: Configuration & File Setup

### 1. Initial Generation
```bash
nixos-generate-config --root /mnt
```

> [!IMPORTANT]
> **Verify Mount Options**: After generation, check `/mnt/etc/nixos/hardware-configuration.nix`. The generator may not capture all Btrfs mount options. Ensure your `fileSystems` entries include `compress=zstd`, `noatime`, and `discard=async`.

### 2. Organize Repo
Clone your config repository or move the prepared files to `/mnt/etc/nixos/`.

The configuration is split into several files for clarity:
- **Flake Entrypoint**: `flake.nix` (defines inputs and host outputs)
- **Host Config**: `hosts/nixos-desktop/configuration.nix` (system-wide settings)
- **User Config**: `home/matt/home.nix` (Home Manager settings)

### 3. Verify Files
Ensure the following files are in place:
- `/mnt/etc/nixos/flake.nix`
- `/mnt/etc/nixos/hosts/nixos-desktop/configuration.nix`
- `/mnt/etc/nixos/hosts/nixos-desktop/hardware-configuration.nix` (Generated in step 1)
- `/mnt/etc/nixos/home/matt/home.nix`

---

## Phase 3: The Final Install
```bash
cd /mnt/etc/nixos
nixos-install --flake .#nixos-desktop
```

---

## Phase 4: Post-Install & Maintenance

### 1. Applying Changes
```bash
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### 2. Updating Packages
```bash
nix flake update
sudo nixos-rebuild switch --flake .#nixos-desktop
```

---

## Appendix: Software Manifest (Verification Checklist)

| Requirement | Scope | Note |
| :--- | :--- | :--- |
| Nvidia Drivers | System | Open drivers with power management & settings GUI. |
| Steam | System | `programs.steam.enable = true` in config. |
| Antigravity IDE | User | Dedicated Flake input and home.nix package. |
| Optimized Kernel | System | CachyOS via flake kernel module. |
| Virtualization | System | KVM + Virt-Manager + Docker. |
| Media | System | VLC & PipeWire (ALSA/Pulse). |
| Desktop Environment | System | GNOME + Niri + DMS. |
| Shell Enhancements | User | starship, fzf, zoxide, eza, bat. |
| Communication | System | Thunderbird & Brave. |

