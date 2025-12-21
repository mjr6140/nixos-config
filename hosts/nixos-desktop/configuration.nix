{ config, pkgs, inputs, ... }:

{
  # Imports
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    ../../modules/packages.nix
  ];

  # Networking (host-specific)
  networking.hostName = "nixos-desktop";

  # Kernel Optimization (CachyOS - desktop-specific)
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linuxPackages_cachyos;

  # Graphics & Nvidia (desktop-specific)
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
  };
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Bluetooth (desktop-specific)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Gaming (desktop-specific)
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # CachyOS kernel cache (desktop-specific)
  nix.settings = {
    substituters = [ "https://nixos-cachyos-kernel.cachix.org" ];
    trusted-public-keys = [ "nixos-cachyos-kernel.cachix.org-1:9Uf4shEitU6p61+nUuW4/V9qVxlYkH9YJbe1KwiI53M=" ];
  };

  system.stateVersion = "25.11";

  # Allow unfree for this evaluation (redundant but safe)
  nixpkgs.config.allowUnfreePredicate = (_: true);
}
