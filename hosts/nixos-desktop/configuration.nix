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

  # Kernel (Latest stable)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Graphics & Nvidia (desktop-specific)
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;  # Disable for desktop
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Nvidia kernel parameters for better Wayland support
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Bluetooth (desktop-specific)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  system.stateVersion = "25.11";
}
