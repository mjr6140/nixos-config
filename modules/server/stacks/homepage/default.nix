{ pkgs, ... }:

let
  homepageConfigDir = "/srv/compose/homepage";
  renderHomepageConfig = pkgs.writeShellScript "render-homepage-config" ''
    set -euo pipefail

    install -d -m 0755 ${homepageConfigDir}
    install -m 0644 ${./config/bookmarks.yaml} ${homepageConfigDir}/bookmarks.yaml
    install -m 0644 ${./config/docker.yaml} ${homepageConfigDir}/docker.yaml
    install -m 0644 ${./config/kubernetes.yaml} ${homepageConfigDir}/kubernetes.yaml
    install -m 0644 ${./config/services.yaml} ${homepageConfigDir}/services.yaml
    install -m 0644 ${./config/settings.yaml} ${homepageConfigDir}/settings.yaml
    install -m 0644 ${./config/widgets.yaml} ${homepageConfigDir}/widgets.yaml
  '';
in
{
  server.dockerComposeApps.instances.homepage = {
    description = "Homepage";
    composeFileSource = ./compose.yaml;
    envDefaults = {
      HOMEPAGE_ALLOWED_HOSTS = "homepage.undead.one,10.12.1.10:3002,127.0.0.1:3002,localhost:3002";
      PUID = "0";
      PGID = "0";
    };
    firewall.allowedTCPPorts = [ 3002 ];
    backup.stopForBackup = false;
  };

  systemd.services.homepage-config = {
    description = "Render Homepage config files";
    wantedBy = [ "multi-user.target" ];
    before = [ "homepage-compose.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = toString renderHomepageConfig;
    };
  };

  systemd.services.homepage-compose.requires = [ "homepage-config.service" ];
  systemd.services.homepage-compose.after = [ "homepage-config.service" ];
}
