{ config, lib, pkgs, ... }:

let
  composeDir = "/srv/compose/pihole";
  composeFile = "${composeDir}/compose.yaml";
  envFile = "${composeDir}/pihole.env";
  secretName = "pihole-web-password";
  hasWebPasswordSecret = builtins.hasAttr secretName config.age.secrets;
  envDefaults = {
    TZ = config.time.timeZone;
    FTLCONF_dns_listeningMode = "all";
    FTLCONF_dns_upstreams = "1.1.1.1;1.0.0.1";
    FTLCONF_webserver_port = "8081";
  };
  envDefaultsText = lib.generators.toKeyValue { } envDefaults;
  envDefaultsFile = pkgs.writeText "pihole.env.defaults" envDefaultsText;
  composeSpec = {
    services.pihole = {
      container_name = "pihole";
      image = "pihole/pihole:latest";
      network_mode = "host";
      restart = "unless-stopped";
      env_file = [ envFile ];
      volumes = [
        "/srv/appdata/pihole/etc-pihole:/etc/pihole"
        "/srv/appdata/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
      ];
    };
  };
  composeFileSource = (pkgs.formats.yaml { }).generate "pihole-compose.yaml" composeSpec;
  projectName = "pihole";
  dockerCmd = lib.getExe config.virtualisation.docker.package;
  composeCmd = "${dockerCmd} compose --project-name ${projectName} --file ${composeFile}";
  renderEnvScript = pkgs.writeShellScript "render-pihole-env" ''
    install -d -m 0755 ${composeDir}
    cp ${envDefaultsFile} ${envFile}
    ${lib.optionalString hasWebPasswordSecret ''
    printf '%s\n' "FTLCONF_webserver_api_password=$(cat ${config.age.secrets.${secretName}.path})" >> ${envFile}
    ''}
    chmod 0600 ${envFile}
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${composeDir} 0755 root root - -"
    "d /srv/appdata/pihole 0755 root root - -"
    "d /srv/appdata/pihole/etc-pihole 0755 root root - -"
    "d /srv/appdata/pihole/etc-dnsmasq.d 0755 root root - -"
    "L+ ${composeFile} - - - - ${composeFileSource}"
  ];

  networking.firewall = {
    allowedTCPPorts = lib.mkAfter [ 53 8081 ];
    allowedUDPPorts = lib.mkAfter [ 53 ];
  };

  systemd.services.pihole-env = {
    description = "Render Pi-hole environment file";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = toString renderEnvScript;
    };
  };

  systemd.services.pihole-compose = {
    description = "Pi-hole via Docker Compose";
    after = [ "docker.service" "network-online.target" "pihole-env.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "pihole-env.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [
      composeFileSource
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
