{
  server.dockerComposeApps.instances.hermes = {
    description = "Hermes AI";
    composeFileSource = ./compose.yaml;
    secretEnvFiles = [ "hermes.env" ];
    appdataDirs = [ "/srv/appdata/hermes" ];
    firewall.allowedTCPPorts = [ 8642 9119 ];
  };
}
