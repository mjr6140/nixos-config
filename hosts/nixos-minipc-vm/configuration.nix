{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker-host.nix
    ../../modules/server/observability-host.nix
    ../../modules/server/pihole.nix
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc-vm";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  virtualisation.vmVariantWithBootLoader = {
    services.btrfs.autoScrub = {
      enable = lib.mkForce false;
      fileSystems = lib.mkForce [ ];
    };
    virtualisation.diskSize = lib.mkForce (40 * 1024);
    virtualisation.sharedDirectories = lib.mkForce { };
  };

  system.stateVersion = "25.11";
}
