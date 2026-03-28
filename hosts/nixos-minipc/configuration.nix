{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker-host.nix
    ../../modules/server/docker-compose-app.nix
    ../../modules/server/observability-host.nix
    ../../modules/server/stacks/caddy
    ../../modules/server/stacks/jellyfin
    ../../modules/server/stacks/karakeep
    ../../modules/server/stacks/pihole
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc";

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
