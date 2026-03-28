{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker-host.nix
    ../../modules/server/docker-compose-app.nix
    ../../modules/server/observability-host.nix
    ../../modules/server/stacks/caddy
    ../../modules/server/stacks/pihole
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc-vm";

  users.users.matt.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com"
  ];

  security.sudo.wheelNeedsPassword = lib.mkForce false;
  services.btrfs.autoScrub = {
    enable = lib.mkForce false;
    fileSystems = lib.mkForce [ ];
  };

  age.identityPaths = [ "/var/lib/agenix/identity" ];
  age.secrets."pihole.env" = {
    file = ../../secrets/pihole.env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  age.secrets."caddy.env" = {
    file = ../../secrets/caddy.env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

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
