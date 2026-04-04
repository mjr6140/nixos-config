{ config, ... }:

{
  server.dockerComposeApps.instances.sabnzbd = {
    description = "Sabnzbd";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      TZ = config.time.timeZone;
    };
    appdataDirs = [
      "/srv/appdata/sabnzbd"
      "/srv/appdata/sabnzbd/config"
    ];
    extraTmpfiles = [
      # linuxserver/sabnzbd runs as the abc user (uid/gid 911) by default.
      "d /srv/appdata/sabnzbd/work 0775 911 911 - -"
    ];
    firewall.allowedTCPPorts = [ 8083 ];
  };
}
