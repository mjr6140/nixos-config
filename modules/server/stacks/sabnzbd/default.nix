{ config, ... }:

{
  server.dockerComposeApps.instances.sabnzbd = {
    description = "Sabnzbd";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      TZ = config.time.timeZone;
    };
    firewall.allowedTCPPorts = [ 8083 ];
  };
}
