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
      "/srv/appdata/sabnzbd/work"
    ];
    firewall.allowedTCPPorts = [ 8083 ];
  };
}
