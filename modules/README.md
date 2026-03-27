# NixOS Configuration Modules

This directory contains shared configuration modules used across multiple hosts.

## Module Structure

### `common.nix`
Contains base system configuration shared across hosts:
- Bootloader settings
- Locale and timezone
- User accounts
- Core hardware services (fwupd)
- Nix settings (flakes, garbage collection, etc.)
- Security hardening, firewall, and maintenance

### `desktop.nix`
Desktop environment configuration:
- GNOME desktop
- GDM display manager
- Niri window manager
- DankMaterialShell
- Desktop fonts and overlays
- Audio, graphics, and XDG portals
- Desktop-adjacent services (printing, Avahi, libvirt, Docker)
- Flatpak/Flathub setup
- Gaming (Steam, GameMode)

### `server/default.nix`
Server-oriented defaults:
- Headless/server-specific settings
- Small overrides that should apply to server hosts but not desktops

### `packages-desktop.nix`
Desktop and desktop-VM system packages:
- Browsers and communication tools
- Workstation apps
- Gaming launchers
- Desktop utilities

### `server/packages.nix`
Server and headless-host system packages:
- Admin tools
- Backup tools
- Minimal shared CLI utilities

### `server/samba-fileserver.nix`
Fileserver SMB sharing:
- Samba shares and WSDD discovery
- Share group and directory permissions
- Share bootstrap directories and service defaults

### `server/snapraid-healthchecks.nix`
SnapRAID healthcheck integration:
- agenix-managed environment secret wiring
- SnapRAID sync/scrub wrappers with Healthchecks pings
- Service overrides to preserve network access for ping delivery

### `server/docker-host.nix`
Docker-host defaults:
- Docker daemon configuration
- Compose/NAS mount tooling
- Shared `/srv/...` directory scaffold

### `server/observability-host.nix`
Observability-host defaults:
- Prometheus
- Grafana
- cAdvisor and node exporter scraping

## Usage

Desktop hosts import the desktop modules:

```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/common.nix
  ../../modules/desktop.nix
  ../../modules/packages-desktop.nix
];
```

Server hosts import the server modules:

```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/common.nix
  ../../modules/server/samba-fileserver.nix
  ../../modules/server/snapraid-healthchecks.nix
  ../../modules/server/default.nix
  ../../modules/server/packages.nix
];
```

## Adding New Packages

To add a desktop application, edit `packages-desktop.nix`:

```nix
environment.systemPackages = with pkgs; [
  # ... existing packages ...
  your-new-package  # Add your package here
];
```

To add a server package, edit `server/packages.nix`.

Then rebuild the relevant host:
```bash
sudo nixos-rebuild switch --flake .#nixos-desktop
# or
sudo nixos-rebuild switch --flake .#nixos-fileserver-vm
```

## Host-Specific Configuration

Each host's `configuration.nix` now only contains:
- Hostname
- Hardware-specific settings
- Host-specific features (VM tools, graphics drivers, Bluetooth, etc.)
