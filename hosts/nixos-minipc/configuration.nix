{ pkgs, lib, ... }:

let
  gluetunSecretFile = ../../secrets/gluetun.env.age;
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker-host.nix
    ../../modules/server/docker-compose-app.nix
    ../../modules/server/observability-host.nix
    ../../modules/server/stacks/arr
    ../../modules/server/stacks/caddy
    ../../modules/server/stacks/gluetun
    ../../modules/server/stacks/jellyfin
    ../../modules/server/stacks/karakeep
    ../../modules/server/stacks/pihole
    ../../modules/server/stacks/sabnzbd
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc";

  services.btrfs.autoScrub = {
    enable = lib.mkForce false;
    fileSystems = lib.mkForce [ ];
  };

  users.users.matt.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com"
  ];

  security.sudo.wheelNeedsPassword = lib.mkForce false;

  age.identityPaths = [ "/var/lib/agenix/identity" ];
  age.secrets = {
    "pihole.env" = {
      file = ../../secrets/pihole.env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "caddy.env" = {
      file = ../../secrets/caddy.env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "karakeep.env" = {
      file = ../../secrets/karakeep.env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  } // lib.optionalAttrs (builtins.pathExists gluetunSecretFile) {
    "gluetun.env" = {
      file = gluetunSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    libva-utils
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  fileSystems."/srv/content/data" = {
    device = "10.12.1.99:/mnt/tank/data";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
    ];
  };

  fileSystems."/srv/content/media" = {
    device = "10.12.1.99:/mnt/tank/data/media";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
    ];
  };

  system.stateVersion = "25.11";
}
