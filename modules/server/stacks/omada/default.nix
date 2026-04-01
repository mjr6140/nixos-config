{
  server.dockerComposeApps.instances.omada = {
    description = "Omada Controller";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      MANAGE_HTTP_PORT = "8088";
      MANAGE_HTTPS_PORT = "8043";
      PORTAL_HTTP_PORT = "8088";
      PORTAL_HTTPS_PORT = "8843";
      PORT_APP_DISCOVERY = "27001";
      PORT_ADOPT_V1 = "29812";
      PORT_UPGRADE_V1 = "29813";
      PORT_MANAGER_V1 = "29811";
      PORT_MANAGER_V2 = "29814";
      PORT_DISCOVERY = "29810";
      PORT_TRANSFER_V2 = "29815";
      PORT_RTTY = "29816";
      SHOW_SERVER_LOGS = "true";
      SHOW_MONGODB_LOGS = "false";
      SSL_CERT_NAME = "tls.crt";
      SSL_KEY_NAME = "tls.key";
      TZ = "Etc/UTC";
    };
    appdataDirs = [
      "/srv/appdata/omada"
      "/srv/appdata/omada/data"
      "/srv/appdata/omada/logs"
    ];
    firewall.allowedTCPPorts = [
      8088
      8043
      8843
      29811
      29812
      29813
      29814
      29815
      29816
      29817
    ];
    firewall.allowedUDPPorts = [
      19810
      27001
      29810
    ];
  };
}
