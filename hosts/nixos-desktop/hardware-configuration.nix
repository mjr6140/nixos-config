{ config, lib, pkgs, modulesPath, ... }:

{
  # Minimal hardware stub for nixos-desktop to allow flake evaluation
  # This file should be replaced by nixos-generate-config on the actual hardware.
  imports = [ ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos"; # Placeholder
      fsType = "btrfs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
