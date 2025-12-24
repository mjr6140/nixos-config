# NixOS Configuration

A modular, flake-based NixOS configuration for gaming and development workstations.

## 🚀 Quick Start

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/nixos-config ~/code/nixos-config
cd ~/code/nixos-config

# Copy your hardware configuration
sudo cp /etc/nixos/hardware-configuration.nix hosts/nixos-desktop/

# Apply configuration
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### Daily Usage
```bash
# Update all flake inputs (nixpkgs, home-manager, etc.)
nix flake update

# Apply the updated configuration
sudo nixos-rebuild switch --flake .#nixos-desktop

# Test configuration before switching
sudo nixos-rebuild test --flake .#nixos-desktop

# Build without activating
sudo nixos-rebuild build --flake .#nixos-desktop

# Format Nix files
nix fmt
```

### Checking What Will Be Updated

When updating your flake, it's helpful to see exactly which packages will change:

```bash
# Method 1: Compare before updating (recommended for planning)
# Build current configuration first
sudo nixos-rebuild build --flake .#nixos-desktop
mv result result-old

# Update the flake
nix flake update

# Build with updated inputs
sudo nixos-rebuild build --flake .#nixos-desktop

# Compare to see what changed (install nvd if needed: nix-shell -p nvd)
nvd diff result-old result

# Method 2: Compare after updating (if you already ran flake update)
# Build the new configuration
sudo nixos-rebuild build --flake .#nixos-desktop

# Compare with your currently running system
nvd diff /run/current-system ./result

# Method 3: Check specific package versions
# Current system
nix-store -q --references /run/current-system | grep package-name

# New build
nix-store -q --references ./result | grep package-name
```

The `nvd` tool shows a clean list of package upgrades, downgrades, additions, and removals with version numbers (e.g., brave 1.71.118 → 1.72.165).

## 📁 Directory Structure

```
.
├── flake.nix                 # Flake entrypoint - defines inputs and outputs
├── flake.lock                # Locked dependency versions
├── docs/                     # Documentation
│   ├── decisions.md          # Design rationale and technical decisions
│   └── install-plan.md       # Detailed installation guide
├── hosts/                    # Host-specific configurations
│   ├── nixos-desktop/        # Gaming/development desktop
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── nixos-vm/             # Testing VM
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── modules/                  # Shared configuration modules
│   ├── README.md
│   ├── common.nix            # Base system config (all hosts)
│   ├── desktop.nix           # Desktop environment (GNOME/Niri)
│   └── packages.nix          # System-wide packages
├── home/                     # Home Manager configurations
│   └── matt/
│       ├── home.nix          # User-level configuration
│       └── qidi-studio.nix   # Custom package derivation
└── overlays/                 # Package overlays and patches
    └── pob-fix.nix           # Path of Building Wayland fixes
```

## 🎯 Features

### System
- **NixOS**: Unstable channel (rolling release)
- **Flakes**: Modern Nix package management with locked dependencies
- **Filesystem**: Btrfs with compression, snapshots, and SSD optimizations
- **Kernel**: Latest stable kernel
- **Graphics**: Nvidia open drivers with Wayland support
- **Audio**: PipeWire (ALSA/Pulse compatibility)
- **Virtualization**: KVM/QEMU, Docker, libvirt
- **Security**: Hardened kernel parameters, firewall, SSH key-only auth

### Desktop Environment
- **Primary**: GNOME 47+ with Wayland
- **Window Manager**: Niri (scrollable tiling)
- **Shell Enhancement**: Dank Material Shell
- **Extensions**: Dash to Panel, AppIndicator, GSConnect, Caffeine

### Development
- **Philosophy**: Per-project environments via `direnv` and `flake.nix`
- **Tools**: Git, Alacritty, modern shell utilities (starship, fzf, zoxide, eza, bat)
- **IDE**: Antigravity (via flake input)
- **AI**: Claude Desktop (via flake input)

### Gaming
- **Platforms**: Steam, Lutris
- **Optimizations**: GameMode
- **Tools**: Path of Building (Rusty PoB with Wayland fixes)

## 🛠️ Common Tasks

### Adding New Packages

**System-wide packages** (available to all users):
```bash
# Edit modules/packages.nix
vim modules/packages.nix

# Add to environment.systemPackages
environment.systemPackages = with pkgs; [
  # ... existing packages ...
  your-new-package
];

# Rebuild
sudo nixos-rebuild switch --flake .#nixos-desktop
```

**User packages** (personal tools):
```bash
# Edit home/matt/home.nix
vim home/matt/home.nix

# Add to home.packages
home.packages = with pkgs; [
  # ... existing packages ...
  your-new-package
];

# Rebuild
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### Adding a New Host

1. Generate hardware configuration:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```

2. Create host directory:
   ```bash
   mkdir -p hosts/new-hostname
   cp /mnt/etc/nixos/hardware-configuration.nix hosts/new-hostname/
   ```

3. Create `hosts/new-hostname/configuration.nix`:
   ```nix
   { config, pkgs, inputs, ... }: {
     imports = [
       ./hardware-configuration.nix
       ../../modules/common.nix
       # Add other modules as needed
     ];
     
     networking.hostName = "new-hostname";
     system.stateVersion = "25.11";
   }
   ```

4. Add to `flake.nix`:
   ```nix
   nixosConfigurations.new-hostname = nixpkgs.lib.nixosSystem {
     # ... (follow pattern from existing hosts)
   };
   ```

### Rolling Back

NixOS keeps previous generations. To rollback:
```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Rollback to specific generation
sudo nix-env --switch-generation 42 --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Cleaning Up

```bash
# Remove old generations older than 30 days
sudo nix-collect-garbage --delete-older-than 30d

# Remove all old generations (keeps current)
sudo nix-collect-garbage -d

# Optimize Nix store (deduplicate files)
nix-store --optimise
```

## 🔒 Security Notes

- SSH configured for **key-based authentication only**
- Place your SSH public key in `/home/matt/.ssh/authorized_keys`
- Root login via SSH is disabled
- Firewall enabled with minimal open ports (22/SSH, 1714-1764/GSConnect)

## 📚 Documentation

- **[Installation Guide](docs/install-plan.md)**: Complete walkthrough from disk partitioning to first boot
- **[Design Decisions](docs/decisions.md)**: Rationale behind configuration choices
- **[Modules README](modules/README.md)**: Understanding the module system

## 🧪 Testing

Before deploying to physical hardware, test in a VM:
```bash
# Build VM configuration
sudo nixos-rebuild switch --flake .#nixos-vm

# Run checks
nix flake check
```

## 🔗 Useful Links

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Package Search](https://search.nixos.org/packages)
- [NixOS Discourse](https://discourse.nixos.org/)

## 📝 License

This configuration is provided as-is for personal use. Feel free to fork and adapt.
