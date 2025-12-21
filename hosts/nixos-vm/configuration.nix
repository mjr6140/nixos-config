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
  networking.hostName = "nixos-vm";

  # Kernel (Standard for VM)
  boot.kernelPackages = pkgs.linuxPackages;

  # KVM Guest Tools (VM-specific)
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  system.stateVersion = "25.11";
}
