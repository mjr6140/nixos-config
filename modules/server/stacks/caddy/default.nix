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
}
