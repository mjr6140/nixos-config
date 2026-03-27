# Shared defaults for Docker-based application hosts.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cifs-utils
    docker-compose
    nfs-utils
  ];

  users.users.matt.extraGroups = [ "docker" ];

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
    daemon.settings = {
      live-restore = true;
      log-driver = "json-file";
      log-opts = {
        max-file = "3";
        max-size = "10m";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/appdata 0755 root root - -"
    "d /srv/compose 0755 root root - -"
    "d /srv/content 0755 root root - -"
    "d /srv/backups 0755 root root - -"
  ];
}
