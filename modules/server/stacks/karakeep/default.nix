{ config, ... }:

{
  server.dockerComposeApps.instances.karakeep = {
    description = "Karakeep";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      KARAKEEP_VERSION = "release";
      DATA_DIR = "/data";
      MEILI_ADDR = "http://meilisearch:7700";
      BROWSER_WEB_URL = "http://chrome:9222";
      MEILI_NO_ANALYTICS = "true";
    };
    secretEnvFiles = [ "karakeep.env" ];
    firewall.allowedTCPPorts = [ 3001 ];
  };
}
