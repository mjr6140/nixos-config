# Shared defaults for hosts that run local observability services.
{ config, ... }:

let
  prometheusPort = 9090;
  cadvisorPort = 8080;
in
{
  services.prometheus = {
    enable = true;
    port = prometheusPort;
    retentionTime = "30d";
    exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
    };
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString prometheusPort}" ];
          }
        ];
      }
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
      {
        job_name = "cadvisor";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString cadvisorPort}" ];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
    };
  };

  services.cadvisor = {
    enable = true;
    port = cadvisorPort;
  };
}
