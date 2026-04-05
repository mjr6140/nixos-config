{ config, pkgs, lib, inputs, nixpkgsInput, ... }:

let
  resticSecretFile = ../../secrets/restic-nixos-desktop.env.age;
  resticSshKeyFile = ../../secrets/restic-nixos-desktop-ssh.age;
  curl = lib.getExe pkgs.curl;
  ping = lib.getExe' pkgs.iputils "ping";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  desktopResticPaths = [
    "/home/matt"
    "/mnt/storage/Photos"
  ];
  desktopResticExcludes = [
    "/home/matt/.cache"
    "/home/matt/.linuxbrew"
    "/home/matt/.local/share/containers"
    "/home/matt/.local/share/flatpak"
    "/home/matt/.local/share/Trash"
    "/home/matt/.steam/steam/steamapps/common"
    "/home/matt/.steam/steam/steamapps/shadercache"
    "/home/matt/.local/share/Steam/steamapps/common"
    "/home/matt/.local/share/Steam/steamapps/shadercache"
    "/home/matt/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/common"
    "/home/matt/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/shadercache"
    "/home/matt/.var/app/*/cache"
    "/home/matt/.local/share/lutris"
    "/home/matt/.local/share/Steam"
    "/home/matt/.codeium"
    "/home/matt/.xlcore"
    "/home/matt/Downloads"
    "/home/matt/Games"
    "/home/matt/VirtualBox VMs"
    "**/__pycache__/"
    "**/node_modules"
    "*.thumbnails"
    "*[Cc]ache*"
    "*[Tt]rash*"
    "/home/matt/.config/Ankama*"
    "/home/matt/mnt"
    "/home/matt/Faugus"
    "/home/matt/.local/share/nixos-minipc-vm/agenix"
  ];
  desktopResticPruneOpts = [
    "--keep-hourly 4"
    "--keep-daily 14"
    "--keep-weekly 4"
    "--keep-monthly 12"
    "--keep-yearly 5"
  ];
  desktopBackupWindow = pkgs.writeShellScript "desktop-restic-backup-window" ''
    set -euo pipefail

    env_file=${config.age.secrets."restic-nixos-desktop.env".path}

    ping_healthchecks() {
      local suffix="$1"
      local ping_url

      ping_url="$(
        set -a
        source "$env_file"
        printf '%s' "''${HC_RESTIC_BACKUPS_URL:-}"
      )"

      if [ -z "$ping_url" ]; then
        echo "Healthchecks ping skipped: HC_RESTIC_BACKUPS_URL is unset in $env_file"
        return 0
      fi

      echo "Pinging desktop restic Healthchecks: $ping_url/$suffix"
      ${curl} \
        --fail \
        --silent \
        --show-error \
        --max-time 10 \
        --retry 2 \
        "$ping_url/$suffix" \
        >/dev/null || true
    }

    backup_status=0

    ping_healthchecks start
    if ${systemctl} start --wait restic-backups-nixos-desktop.service; then
      ping_healthchecks 0
    else
      backup_status=$?
      ping_healthchecks "$backup_status"
      exit "$backup_status"
    fi
  '';
in

{
  # Imports
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    ../../modules/llama-cpp-desktop.nix
    ../../modules/packages-desktop.nix
  ];

  # Networking (host-specific)
  networking.hostName = "nixos-desktop";

  age.identityPaths = [ "/var/lib/agenix/identity" ];
  age.secrets =
    lib.optionalAttrs (builtins.pathExists resticSecretFile) {
      "restic-nixos-desktop.env" = {
        file = resticSecretFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    }
    // lib.optionalAttrs (builtins.pathExists resticSshKeyFile) {
      "restic-nixos-desktop-ssh" = {
        file = resticSshKeyFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

  services.restic.backups = lib.optionalAttrs
    (builtins.pathExists resticSecretFile && builtins.pathExists resticSshKeyFile) {
    nixos-desktop = {
      environmentFile = config.age.secrets."restic-nixos-desktop.env".path;
      paths = desktopResticPaths;
      exclude = desktopResticExcludes;
      initialize = true;
      pruneOpts = desktopResticPruneOpts;
      createWrapper = true;
      extraOptions = [
        "sftp.args='-i ${config.age.secrets."restic-nixos-desktop-ssh".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/.ssh/known_hosts'"
      ];
      timerConfig = null;
      backupPrepareCommand = ''
        #!${pkgs.runtimeShell}
        for i in $(seq 1 30); do
          ${ping} -c1 -W1 10.12.1.99 >/dev/null 2>&1 && exit 0
          sleep 2
        done
        echo "Backup host unreachable" >&2
        exit 1
      '';
    };
  };

  systemd.services.restic-backups-desktop-window = lib.mkIf
    (builtins.pathExists resticSecretFile && builtins.pathExists resticSshKeyFile) {
      description = "Desktop restic backup window";
      wants = [ "network-online.target" "restic-backups-nixos-desktop.service" ];
      after = [ "network-online.target" ];
      path = [ pkgs.curl pkgs.systemd ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = desktopBackupWindow;
      };
    };

  systemd.timers.restic-backups-desktop-window = lib.mkIf
    (builtins.pathExists resticSecretFile && builtins.pathExists resticSshKeyFile) {
      description = "Run desktop restic backup hourly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = false;
      };
      unitConfig.X-OnlyManualStart = true;
    };

  # Kernel (Latest stable)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # SCX scheduler
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  # Graphics & Nvidia (desktop-specific)
  boot.blacklistedKernelModules = [ "nouveau" ];
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;  # Disable for desktop
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Nvidia kernel parameters for better Wayland support
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Nvidia suspend/resume fixes
  # https://discourse.nixos.org/t/suspend-resume-cycling-on-system-resume/32322/10
  systemd = {
     services."gnome-suspend" = {
      description = "suspend gnome shell";
      before = [
        "systemd-suspend.service" 
        "systemd-hibernate.service"
        "nvidia-suspend.service"
        "nvidia-hibernate.service"
      ];
      wantedBy = [
        "systemd-suspend.service"
        "systemd-hibernate.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${pkgs.procps}/bin/pkill -STOP gnome-shell'';
      };
    };
    services."gnome-resume" = {
      description = "resume gnome shell";
      after = [
        "systemd-suspend.service" 
        "systemd-hibernate.service"
        "nvidia-resume.service"
      ];
      wantedBy = [
        "systemd-suspend.service"
        "systemd-hibernate.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${pkgs.procps}/bin/pkill -CONT gnome-shell'';
      };
    };
  };

  # Bluetooth (desktop-specific)
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  system.stateVersion = "25.11";
}
