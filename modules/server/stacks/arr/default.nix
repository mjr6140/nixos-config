{ config, ... }:

{
  server.dockerComposeApps.instances.arr = {
    description = "Prowlarr, Radarr, and Sonarr";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      TZ = config.time.timeZone;
    };
    requiredMounts = [ "/srv/content/data" ];
    firewall.allowedTCPPorts = [ 7878 8989 9696 ];
  };
}
