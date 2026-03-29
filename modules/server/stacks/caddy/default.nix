{ config, lib, pkgs, ... }:

let
  docker = lib.getExe config.virtualisation.docker.package;
  reloadCaddy = pkgs.writeShellScript "reload-caddy" ''
    set -euo pipefail

    if ! ${docker} inspect -f '{{.State.Running}}' caddy >/dev/null 2>&1; then
      echo "Caddy reload skipped: container is not running"
      exit 0
    fi

    echo "Reloading Caddy config in running container"
    ${docker} exec caddy caddy reload --config /etc/caddy/Caddyfile
  '';
in
{
  server.dockerComposeApps.instances.caddy = {
    description = "Caddy";
    composeFileSource = ./compose.yaml;
    extraFiles = {
      Caddyfile = ./Caddyfile;
    };
    envDefaults = { };
    secretEnvFiles = [ "caddy.env" ];
    backup.stopForBackup = false;
    appdataDirs = [
      "/srv/appdata/caddy"
      "/srv/appdata/caddy/data"
      "/srv/appdata/caddy/config"
    ];
    firewall.allowedTCPPorts = [ 80 443 ];
    firewall.allowedUDPPorts = [ 443 ];
  };

  systemd.services.caddy-reload = {
    description = "Reload Caddy config in-container";
    after = [ "docker.service" "caddy-compose.service" ];
    requires = [ "docker.service" "caddy-compose.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = toString reloadCaddy;
    };
  };

  systemd.paths.caddy-reload = {
    description = "Watch Caddy config for reload";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/srv/compose/caddy/Caddyfile";
      Unit = "caddy-reload.service";
    };
  };
}
