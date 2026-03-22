{ config, lib, pkgs, ... }:

let
  dataMounts = [
    "/mnt/disk1"
    "/mnt/disk2"
    "/mnt/disk3"
  ];

  dataDirs = map (mount: "${mount}/data") dataMounts;
  storageMounts = dataMounts ++ [
    "/mnt/parity"
    "/srv/storage"
  ];
in
{
  system.fsPackages = [ pkgs.mergerfs ];

  environment.systemPackages = with pkgs; [
    mergerfs-tools
    smartmontools
  ];

  programs.fuse.userAllowOther = true;

  fileSystems."/mnt/disk1" = {
    device = "/dev/disk/by-label/fs-disk1";
    fsType = "ext4";
  };

  fileSystems."/mnt/disk2" = {
    device = "/dev/disk/by-label/fs-disk2";
    fsType = "ext4";
  };

  fileSystems."/mnt/disk3" = {
    device = "/dev/disk/by-label/fs-disk3";
    fsType = "ext4";
  };

  fileSystems."/mnt/parity" = {
    device = "/dev/disk/by-label/fs-parity";
    fsType = "ext4";
  };

  systemd.tmpfiles.rules =
    [ "d /var/lib/snapraid 0755 root root - -" ]
    ++ map (dir: "d ${dir} 0755 root root - -") dataDirs;

  fileSystems."/srv/storage" = {
    device = builtins.concatStringsSep ":" dataDirs;
    fsType = "fuse.mergerfs";
    depends = dataMounts ++ [ "/mnt/parity" ];
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=mfs"
      "moveonenospc=true"
      "minfreespace=1G"
      "fsname=mergerfs"
    ];
  };

  services.snapraid = {
    enable = true;
    dataDisks = {
      d1 = "${builtins.elemAt dataDirs 0}/";
      d2 = "${builtins.elemAt dataDirs 1}/";
      d3 = "${builtins.elemAt dataDirs 2}/";
    };
    parityFiles = [ "/mnt/parity/snapraid.parity" ];
    contentFiles = [
      "/var/lib/snapraid/snapraid.content"
      "/mnt/disk1/snapraid.content"
      "/mnt/disk2/snapraid.content"
      "/mnt/disk3/snapraid.content"
      "/mnt/parity/snapraid.content"
    ];
    exclude = [
      "/tmp/"
      "/lost+found/"
      ".DS_Store"
      "Thumbs.db"
    ];
    extraConfig = ''
      nohidden
      pool /srv/storage
    '';
    sync.interval = "03:00";
    scrub = {
      interval = "Sun *-*-* 04:00:00";
      plan = 12;
      olderThan = 10;
    };
  };

  virtualisation.vmVariantWithBootLoader.virtualisation.fileSystems = lib.mkForce (
    {
      "/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
    }
    // builtins.listToAttrs (
      map (mountPoint: {
        name = mountPoint;
        value = config.fileSystems.${mountPoint};
      }) storageMounts
    )
  );
}
