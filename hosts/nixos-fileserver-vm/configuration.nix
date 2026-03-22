{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./storage.nix
    ../../modules/common.nix
    ../../modules/samba-fileserver.nix
    ../../modules/server.nix
    ../../modules/packages-server.nix
  ];

  networking.hostName = "nixos-fileserver-vm";

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
