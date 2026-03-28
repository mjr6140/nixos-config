{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./storage.nix
    ../../modules/common.nix
    ../../modules/server/samba-fileserver.nix
    ../../modules/server/snapraid-healthchecks.nix
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-fileserver-vm";

  users.users.matt.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com"
  ];

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
