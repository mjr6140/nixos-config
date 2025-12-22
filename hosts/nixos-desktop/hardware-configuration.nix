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
    { device = "/dev/disk/by-uuid/<uuid>";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd" "noatime" "discard=async"];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/<uuid>";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd" "noatime" "discard=async"];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/<uuid>";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd" "noatime" "discard=async"];
    };

  fileSystems."/var/log" =
    { device = "/dev/disk/by-uuid/<uuid>";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd" "noatime" "discard=async"];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/<uuid-efs-boot>";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  # Storage mount for photos disk
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/51BAE4A7240C12DE";
    fsType = "auto";
    options = [
      "nosuid"
      "nodev"
      "nofail"
      "x-gvfs-show"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
