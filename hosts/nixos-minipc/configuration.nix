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
  combinedBackupWindow = pkgs.writeShellScript "combined-restic-backup-window" ''
    set -euo pipefail

    local_env=${config.age.secrets."restic-nixos-minipc.env".path}
    vps_env=${config.age.secrets."restic-nixos-minipc-vps.env".path}

    ping_healthchecks() {
      local label="$1"
      local env_file="$2"
      local suffix="$3"
      local ping_url

      ping_url="$(
        set -a
        source "$env_file"
        printf '%s' "''${HC_RESTIC_BACKUPS_URL:-}"
      )"

      if [ -z "$ping_url" ]; then
        echo "Healthchecks ping skipped for $label: HC_RESTIC_BACKUPS_URL is unset in $env_file"
        return 0
      fi

      echo "Pinging Healthchecks for $label: $ping_url/$suffix"
      ${curl} \
        --fail \
        --silent \
        --show-error \
        --max-time 10 \
        --retry 2 \
        "$ping_url/$suffix" \
        >/dev/null || true
    }

    cleanup() {
      ${startBackupComposeStacks}
    }

    trap cleanup EXIT

    ${stopBackupComposeStacks}

    local_status=0
    vps_status=0

    echo "Running local NAS backup job"
    ping_healthchecks "local restic backup start" "$local_env" start
    if ${systemctl} start --wait restic-backups-nixos-minipc.service; then
      ping_healthchecks "local restic backup result" "$local_env" 0
    else
      local_status=$?
      ping_healthchecks "local restic backup result" "$local_env" "$local_status"
    fi

    echo "Running VPS backup job"
    ping_healthchecks "VPS restic backup start" "$vps_env" start
    if ${systemctl} start --wait restic-backups-nixos-minipc-vps.service; then
      ping_healthchecks "VPS restic backup result" "$vps_env" 0
    else
      vps_status=$?
      ping_healthchecks "VPS restic backup result" "$vps_env" "$vps_status"
    fi

    if [ "$local_status" -ne 0 ] || [ "$vps_status" -ne 0 ]; then
      echo "Combined backup window failed: local_status=$local_status vps_status=$vps_status"
      exit 1
    fi

    echo "Combined backup window completed successfully"
  '';
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
    ../../modules/server/stacks/homepage
    ../../modules/server/stacks/jellyfin
    ../../modules/server/stacks/karakeep
    ../../modules/server/stacks/omada
    ../../modules/server/stacks/pihole
    ../../modules/server/stacks/sabnzbd
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc";
  networking.firewall.allowPing = true;

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
      pruneOpts = resticCommonPruneOpts;
      timerConfig = null;
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
        pruneOpts = resticCommonPruneOpts;
        timerConfig = null;
        extraOptions = [
          "sftp.args='-i ${config.age.secrets."restic-nixos-minipc-vps-ssh".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/.ssh/known_hosts'"
        ];
        createWrapper = true;
      };
    };

  systemd.services.restic-backups-nixos-minipc = lib.mkIf
    (builtins.pathExists resticSecretFile)
    {
      serviceConfig.RestrictAddressFamilies = lib.mkForce [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };

  systemd.services.restic-backups-nixos-minipc-vps = lib.mkIf
    (builtins.pathExists resticVpsSecretFile && builtins.pathExists resticVpsSshKeyFile)
    {
      serviceConfig.RestrictAddressFamilies = lib.mkForce [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };

  systemd.services.restic-backups-window = lib.mkIf
    (builtins.pathExists resticSecretFile
      && builtins.pathExists resticVpsSecretFile
      && builtins.pathExists resticVpsSshKeyFile)
    {
      description = "Combined restic backup window for nixos-minipc";
      after = [
        "network-online.target"
        "restic-backups-nixos-minipc.service"
        "restic-backups-nixos-minipc-vps.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = toString combinedBackupWindow;
        TimeoutStartSec = 0;
      };
    };

  systemd.timers.restic-backups-window = lib.mkIf
    (builtins.pathExists resticSecretFile
      && builtins.pathExists resticVpsSecretFile
      && builtins.pathExists resticVpsSshKeyFile)
    {
      description = "Run combined restic backup window";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "03:15";
        RandomizedDelaySec = "45m";
        Persistent = true;
      };
    };

  system.stateVersion = "25.11";
}
