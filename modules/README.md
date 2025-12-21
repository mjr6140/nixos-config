# NixOS Configuration Modules

This directory contains shared configuration modules used across multiple hosts.

## Module Structure

### `common.nix`
Contains all shared system configuration:
- Bootloader settings
- Locale and timezone
- Fonts
- Audio (PipeWire)
- Virtualisation (libvirt, Docker)
- User accounts
- Hardware services (printing, Flatpak, etc.)
- Nix settings (flakes, garbage collection, etc.)

### `desktop.nix`
Desktop environment configuration:
- GNOME desktop
- GDM display manager
- Niri window manager
- DankMaterialShell

### `packages.nix`
**This is where you add new applications!**

All system-wide packages that should be available on both hosts. When you want to add a new app, just add it to the `environment.systemPackages` list in this file.

## Usage

Both `nixos-vm` and `nixos-desktop` import these modules in their `configuration.nix`:

```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/common.nix
  ../../modules/desktop.nix
  ../../modules/packages.nix
];
```

## Adding New Applications

To add a new application to both hosts, edit `packages.nix`:

```nix
environment.systemPackages = with pkgs; [
  # ... existing packages ...
  your-new-package  # Add your package here
];
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake .#nixos-vm
# or
sudo nixos-rebuild switch --flake .#nixos-desktop
```

## Host-Specific Configuration

Each host's `configuration.nix` now only contains:
- Hostname
- Hardware-specific settings (kernel, graphics drivers, etc.)
- Host-specific features (VM tools, gaming, Bluetooth, etc.)
