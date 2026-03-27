{ config, ... }:

{
  server.dockerComposeApps.instances.pihole = {
    description = "Pi-hole";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      TZ = config.time.timeZone;
      FTLCONF_dns_listeningMode = "all";
      FTLCONF_dns_upstreams = "1.1.1.1;1.0.0.1";
      FTLCONF_webserver_port = "8081";
    };
    secretEnv = {
      FTLCONF_webserver_api_password = "pihole-web-password";
    };
    firewall.allowedTCPPorts = [ 53 8081 ];
    firewall.allowedUDPPorts = [ 53 ];
  };
}
