{ pkgs, lib, ... }:

let
  gluetunSecretFile = ../../secrets/gluetun.env.age;
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
    ../../modules/server/stacks/omada
    ../../modules/server/stacks/pihole
    ../../modules/server/stacks/sabnzbd
    ../../modules/server/default.nix
    ../../modules/server/packages.nix
  ];

  networking.hostName = "nixos-minipc-vm";

  users.users.matt.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlo4CgrsAdGMbal1HgyaUF8lFYol6DmXZgskdxFt776 mjr6140@gmail.com"
  ];

  security.sudo.wheelNeedsPassword = lib.mkForce false;
  services.btrfs.autoScrub = {
    enable = lib.mkForce false;
    fileSystems = lib.mkForce [ ];
  };

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
  } // lib.optionalAttrs (builtins.pathExists gluetunSecretFile) {
    "gluetun.env" = {
      file = gluetunSecretFile;
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  systemd.services.grow-rootfs = {
    description = "Grow root partition and filesystem to fill the VM disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    wants = [ "local-fs.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/grow-rootfs.done";
    path = with pkgs; [
      cloud-utils
      coreutils
      e2fsprogs
      gawk
      gnugrep
      util-linux
    ];
    script = ''
      set -euo pipefail

      root_source="$(findmnt -n -o SOURCE /)"
      root_kname="$(basename "$(readlink -f "$root_source")")"
      disk_name="$(lsblk -no PKNAME "$root_source")"
      part_num="$(cat "/sys/class/block/$root_kname/partition")"

      if [[ -z "$disk_name" || -z "$part_num" ]]; then
        echo "Could not determine disk/partition for root filesystem: $root_source" >&2
        exit 1
      fi

      growpart "/dev/$disk_name" "$part_num"
      resize2fs "$root_source"

      install -D -m 0644 /dev/null /var/lib/grow-rootfs.done
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
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

  virtualisation.vmVariantWithBootLoader = {
    services.btrfs.autoScrub = {
      enable = lib.mkForce false;
      fileSystems = lib.mkForce [ ];
    };
    virtualisation.diskSize = lib.mkForce (40 * 1024);
    virtualisation.sharedDirectories = lib.mkForce { };
  };

  system.stateVersion = "25.11";
}
