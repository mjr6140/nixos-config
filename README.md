# NixOS Configuration

Flake-based NixOS configuration for gaming and development workstations.

## Common Tasks

### Apply or Test a Configuration
```bash
# Apply changes
sudo nixos-rebuild switch --flake .#nixos-desktop

# Validate without switching
sudo nixos-rebuild test --flake .#nixos-desktop

# Build without activating
sudo nixos-rebuild build --flake .#nixos-desktop
```

### Update Inputs (nixpkgs, home-manager, etc.)
```bash
nix flake update
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### See What Will Change
```bash
# If you've already run `nix flake update`, compare the new build to the
# currently running system.
sudo nixos-rebuild build --flake .#nixos-desktop

# Compare builds (install nvd if needed: nix-shell -p nvd)
nvd diff /run/current-system result
```

### Add a System Package (all users)
```bash
# Edit modules/packages.nix
vim modules/packages.nix

# Add to environment.systemPackages, then rebuild
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### Add a User Package (Home Manager)
```bash
# Edit home/matt/home.nix
vim home/matt/home.nix

# Add to home.packages, then rebuild
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### Add a New Host
```bash
# Create host directory and copy hardware config
mkdir -p hosts/new-hostname
sudo cp /etc/nixos/hardware-configuration.nix hosts/new-hostname/
```

Create `hosts/new-hostname/configuration.nix`:
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

Add the host to `flake.nix`, following the existing pattern, then:
```bash
sudo nixos-rebuild switch --flake .#new-hostname
```

### Roll Back
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Roll back to previous generation
sudo nixos-rebuild switch --rollback
```

### Clean Old Generations
```bash
# Remove old generations older than 30 days
sudo nix-collect-garbage --delete-older-than 30d

# Remove all old generations (keeps current)
sudo nix-collect-garbage -d
```

### Format Nix Files
```bash
nix fmt
```

## Directory Structure (short)

```
.
├── flake.nix                 # Flake entrypoint - inputs and outputs
├── flake.lock                # Locked dependency versions
├── hosts/                    # Host-specific configurations
├── modules/                  # Shared system modules
├── home/                     # Home Manager configurations
├── overlays/                 # Package overrides/patches
└── docs/                     # Supporting documentation
```

## Documentation

- **[Installation Guide](docs/install-plan.md)**: Disk setup and first boot
- **[Design Decisions](docs/decisions.md)**: Rationale behind configuration choices
- **[Modules README](modules/README.md)**: Module structure and shared options

## Testing

```bash
# Validate the flake
nix flake check

# Build VM configuration
sudo nixos-rebuild switch --flake .#nixos-vm
```

## Useful Links

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Package Search](https://search.nixos.org/packages)
- [NixOS Discourse](https://discourse.nixos.org/)
## License

This configuration is provided as-is for personal use. Feel free to fork and adapt.
