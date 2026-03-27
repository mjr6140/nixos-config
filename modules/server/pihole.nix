{ config, lib, pkgs, ... }:

let
  composeDir = "/srv/compose/pihole";
  composeFile = "${composeDir}/compose.yaml";
  composeFileSource = ../../hosts/nixos-minipc/compose/pihole/compose.yaml;
  envFile = "${composeDir}/pihole.env";
  envFileSource = pkgs.writeText "pihole.env" ''
    # Leave the password unset for now; Pi-hole will generate one on first boot
    # and print it to the container logs. Replace this later with a secret-backed
    # FTLCONF_webserver_api_password or WEBPASSWORD_FILE workflow.
    TZ=${config.time.timeZone}
    FTLCONF_dns_listeningMode=all
    FTLCONF_dns_upstreams=1.1.1.1;1.0.0.1
    FTLCONF_webserver_port=8081
  '';
  projectName = "pihole";
  dockerCmd = lib.getExe config.virtualisation.docker.package;
  composeCmd = "${dockerCmd} compose --project-name ${projectName} --file ${composeFile}";
in
{
  systemd.tmpfiles.rules = [
    "d ${composeDir} 0755 root root - -"
    "d /srv/appdata/pihole 0755 root root - -"
    "d /srv/appdata/pihole/etc-pihole 0755 root root - -"
    "d /srv/appdata/pihole/etc-dnsmasq.d 0755 root root - -"
    "L+ ${composeFile} - - - - ${composeFileSource}"
    "L+ ${envFile} - - - - ${envFileSource}"
  ];

  networking.firewall = {
    allowedTCPPorts = lib.mkAfter [ 53 8081 ];
    allowedUDPPorts = lib.mkAfter [ 53 ];
  };

  systemd.services.pihole-compose = {
    description = "Pi-hole via Docker Compose";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [
      composeFileSource
      envFileSource
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = composeDir;
      ExecStart = "${composeCmd} up -d --remove-orphans";
      ExecStop = "${composeCmd} down";
      TimeoutStartSec = 0;
    };
  };
}
