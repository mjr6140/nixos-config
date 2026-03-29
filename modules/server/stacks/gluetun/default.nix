{
  server.dockerComposeApps.instances.gluetun = {
    description = "Gluetun";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      VPN_SERVICE_PROVIDER = "airvpn";
      VPN_TYPE = "wireguard";
      SERVER_COUNTRIES = "Canada";
      FIREWALL_VPN_INPUT_PORTS = "35291";
    };
    secretEnvFiles = [ "gluetun.env" ];
    appdataDirs = [ "/srv/appdata/gluetun" ];
    firewall.allowedTCPPorts = [ 8082 ];
  };
}
