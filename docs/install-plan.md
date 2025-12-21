# NixOS Installation Guide: Gaming & Development

This guide follows a chronological path to a fully optimized NixOS system using **Btrfs**, **Flakes**, and **Home Manager**.

---

## Phase 1: Disk Partitioning & Btrfs Layout
*Refer to the original Obsidian note for detailed terminal commands.*

---

## Phase 2: Configuration & File Setup

### 1. Initial Generation
```bash
nixos-generate-config --root /mnt
```

### 2. Organize Repo
Clone your config repository or move the prepared files to `/mnt/etc/nixos/`.

The configuration is split into several files for clarity:
- **Flake Entrypoint**: `flake.nix` (defines inputs and host outputs)
- **Host Config**: `hosts/gaming-pc/configuration.nix` (system-wide settings)
- **User Config**: `home/matt/home.nix` (Home Manager settings)

### 3. Verify Files
Ensure the following files are in place:
- `/mnt/etc/nixos/flake.nix`
- `/mnt/etc/nixos/hosts/gaming-pc/configuration.nix`
- `/mnt/etc/nixos/hosts/gaming-pc/hardware-configuration.nix` (Generated in step 1)
- `/mnt/etc/nixos/home/matt/home.nix`

---

## Phase 3: The Final Install
```bash
cd /mnt/etc/nixos
nixos-install --flake .#gaming-pc
```

---

## Phase 4: Post-Install & Maintenance

### 1. Applying Changes
```bash
sudo nixos-rebuild switch --flake .#gaming-pc
```

### 2. Updating Packages
```bash
nix flake update
sudo nixos-rebuild switch --flake .#gaming-pc
```
