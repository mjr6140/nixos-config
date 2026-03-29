{ config, pkgs, lib, ... }:

let
  gluetunSecretFile = ../../secrets/gluetun.env.age;
  resticSecretFile = ../../secrets/restic-nixos-minipc.env.age;
  resticVpsSecretFile = ../../secrets/restic-nixos-minipc-vps.env.age;
  resticVpsSshKeyFile = ../../secrets/restic-nixos-minipc-vps-ssh.age;
  curl = lib.getExe pkgs.curl;
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  backupStoppedComposeUnits =
    map (name: "${name}-compose") (
      builtins.attrNames (
        lib.filterAttrs (_: instance: instance.backup.stopForBackup)
          config.server.dockerComposeApps.instances
      )
    );
  stopBackupComposeStacks = pkgs.writeShellScript "stop-backup-compose-stacks" ''
    set -euo pipefail
    ${lib.optionalString (backupStoppedComposeUnits != [ ]) ''
      echo "Stopping stacks for backup: ${lib.concatStringsSep " " backupStoppedComposeUnits}"
      ${systemctl} stop ${lib.concatStringsSep " " backupStoppedComposeUnits}
    ''}
    ${lib.optionalString (backupStoppedComposeUnits == [ ]) ''
      echo "No compose stacks marked to stop for backup"
    ''}
  '';
  startBackupComposeStacks = pkgs.writeShellScript "start-backup-compose-stacks" ''
    set -euo pipefail
    ${lib.optionalString (backupStoppedComposeUnits != [ ]) ''
      echo "Starting stacks after backup: ${lib.concatStringsSep " " backupStoppedComposeUnits}"
      ${systemctl} start ${lib.concatStringsSep " " backupStoppedComposeUnits}
    ''}
    ${lib.optionalString (backupStoppedComposeUnits == [ ]) ''
      echo "No compose stacks marked to restart after backup"
    ''}
  '';
  pingResticHealthchecksStart = ''
    set -u
    ping_url="''${HC_RESTIC_BACKUPS_URL:-}"
    if [ -z "$ping_url" ]; then
      echo "Healthchecks ping skipped for restic backup start: HC_RESTIC_BACKUPS_URL is unset"
      exit 0
    fi
    echo "Pinging Healthchecks for restic backup start: $ping_url/start"
    ${curl} \
      --fail \
      --silent \
      --show-error \
      --max-time 10 \
      --retry 2 \
      "$ping_url/start" \
      >/dev/null || true
  '';
  pingResticHealthchecksResult = ''
    set -u
    ping_url="''${HC_RESTIC_BACKUPS_URL:-}"
    if [ -z "$ping_url" ]; then
      echo "Healthchecks result ping skipped for restic backup: HC_RESTIC_BACKUPS_URL is unset"
      exit 0
    fi
    status="''${EXIT_STATUS:-1}"
    if [ "''${SERVICE_RESULT:-}" = "success" ]; then
      status=0
    fi
    echo "Pinging Healthchecks for restic backup result: $ping_url/$status"
    ${curl} \
      --fail \
      --silent \
      --show-error \
      --max-time 10 \
      --retry 2 \
      "$ping_url/$status" \
      >/dev/null || true
  '';
  resticCommonPaths = [
    "/srv/appdata"
    "/var/lib/agenix/identity"
    "/etc/ssh"
  ];
  resticCommonExcludes = [
    "/srv/appdata/**/Cache"
    "/srv/appdata/**/cache"
  ];
  resticCommonPruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
  ];
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/server/docker-host.nix
    ../../modules/server/docker-compose-app.nix
    ../../modules/server/observability-host.nix
    ../../modules/server/stacks/arr
    ../../modules/server/stacks/caddy
    ../../modules/server/stacks/gluetun
    ../../modules/server/stacks/jellyfin
    ../../modules/server/stacks/karakeep
    ../../modules/server/stacks/pihole
    ../../modules/server/stacks/sabnzbd
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc";
  networking.firewall.allowPing = true;

  services.btrfs.autoScrub = {
    enable = lib.mkForce false;
    fileSystems = lib.mkForce [ ];
  };

  users.users.matt.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com"
  ];

  security.sudo.wheelNeedsPassword = lib.mkForce false;

  age.identityPaths = [ "/var/lib/agenix/identity" ];
  age.secrets = {
    "pihole.env" = {
      file = ../../secrets/pihole.env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "caddy.env" = {
      file = ../../secrets/caddy.env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "karakeep.env" = {
      file = ../../secrets/karakeep.env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  }
  // lib.optionalAttrs (builtins.pathExists gluetunSecretFile) {
    "gluetun.env" = {
      file = gluetunSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  }
  // lib.optionalAttrs (builtins.pathExists resticSecretFile) {
    "restic-nixos-minipc.env" = {
      file = resticSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  }
  // lib.optionalAttrs (builtins.pathExists resticVpsSecretFile) {
    "restic-nixos-minipc-vps.env" = {
      file = resticVpsSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  }
  // lib.optionalAttrs (builtins.pathExists resticVpsSshKeyFile) {
    "restic-nixos-minipc-vps-ssh" = {
      file = resticVpsSshKeyFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    libva-utils
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  fileSystems."/srv/content/data" = {
    device = "10.12.1.99:/mnt/tank/data";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
    ];
  };

  fileSystems."/srv/content/media" = {
    device = "10.12.1.99:/mnt/tank/data/media";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
    ];
  };

  fileSystems."/mnt/backup-repos" = {
    device = "10.12.1.99:/mnt/tank/backup-repos";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
    ];
  };

  services.restic.backups = lib.optionalAttrs (builtins.pathExists resticSecretFile) {
    nixos-minipc = {
      paths = resticCommonPaths;
      exclude = resticCommonExcludes;
      repository = "/mnt/backup-repos/restic/nixos-minipc";
      environmentFile = config.age.secrets."restic-nixos-minipc.env".path;
      initialize = true;
      backupPrepareCommand = toString stopBackupComposeStacks;
      backupCleanupCommand = toString startBackupComposeStacks;
      pruneOpts = resticCommonPruneOpts;
      timerConfig = {
        OnCalendar = "03:15";
        RandomizedDelaySec = "45m";
        Persistent = true;
      };
      createWrapper = true;
    };
  } // lib.optionalAttrs
    (builtins.pathExists resticVpsSecretFile && builtins.pathExists resticVpsSshKeyFile)
    {
      nixos-minipc-vps = {
        paths = resticCommonPaths;
        exclude = resticCommonExcludes;
        repository = "sftp:restic@185.45.112.73:/data/backup-repos/restic/nixos-minipc";
        environmentFile = config.age.secrets."restic-nixos-minipc-vps.env".path;
        initialize = true;
        backupPrepareCommand = toString stopBackupComposeStacks;
        backupCleanupCommand = toString startBackupComposeStacks;
        pruneOpts = resticCommonPruneOpts;
        timerConfig = {
          OnCalendar = "04:30";
          RandomizedDelaySec = "45m";
          Persistent = true;
        };
        extraOptions = [
          "sftp.args='-i ${config.age.secrets."restic-nixos-minipc-vps-ssh".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/.ssh/known_hosts'"
        ];
        createWrapper = true;
      };
    };

  systemd.services.restic-backups-nixos-minipc = lib.mkIf
    (builtins.pathExists resticSecretFile)
    {
      serviceConfig.EnvironmentFile = [ "-${config.age.secrets."restic-nixos-minipc.env".path}" ];
      serviceConfig.RestrictAddressFamilies = lib.mkForce [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      preStart = lib.mkAfter pingResticHealthchecksStart;
      postStop = lib.mkAfter pingResticHealthchecksResult;
    };

  systemd.services.restic-backups-nixos-minipc-vps = lib.mkIf
    (builtins.pathExists resticVpsSecretFile && builtins.pathExists resticVpsSshKeyFile)
    {
      serviceConfig.EnvironmentFile = [ "-${config.age.secrets."restic-nixos-minipc-vps.env".path}" ];
      serviceConfig.RestrictAddressFamilies = lib.mkForce [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      preStart = lib.mkAfter pingResticHealthchecksStart;
      postStop = lib.mkAfter pingResticHealthchecksResult;
    };

  system.stateVersion = "25.11";
}
