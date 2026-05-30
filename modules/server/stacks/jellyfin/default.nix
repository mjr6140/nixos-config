{ config, ... }:

{
  server.dockerComposeApps.instances.jellyfin = {
    description = "Jellyfin";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      TZ = config.time.timeZone;
      JELLYFIN_PublishedServerUrl = "http://10.12.1.10:8096";
    };
    requiredMounts = [ "/srv/content/media" ];
    firewall.allowedTCPPorts = [ 8096 ];
    firewall.allowedUDPPorts = [ 1900 7359 ];
  };
}
