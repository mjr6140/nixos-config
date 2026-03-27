{ lib, pkgs, ... }:

let
  shareGroup = "sambashare";
  shareRoot = "/srv/storage/shares";

  mkWritableShare = path: comment: {
    inherit path comment;
    "browseable" = "yes";
    "read only" = "no";
    "valid users" = "@${shareGroup}";
    "force group" = shareGroup;
    "create mask" = "0664";
    "directory mask" = "2775";
  };
in
{
  users.groups.${shareGroup} = { };
  users.users.matt.extraGroups = lib.mkAfter [ shareGroup ];

  systemd.tmpfiles.rules = [
    "d ${shareRoot} 2775 root ${shareGroup} - -"
    "d ${shareRoot}/shared 2775 root ${shareGroup} - -"
    "d ${shareRoot}/media 2775 root ${shareGroup} - -"
  ];

  systemd.services.samba-share-setup = {
    description = "Ensure Samba share directories exist on the storage pool";
    after = [ "srv-storage.mount" ];
    requires = [ "srv-storage.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
    path = [ pkgs.coreutils ];
    script = ''
      mkdir -p ${shareRoot}/shared ${shareRoot}/media
      chgrp ${shareGroup} ${shareRoot} ${shareRoot}/shared ${shareRoot}/media
      chmod 2775 ${shareRoot} ${shareRoot}/shared ${shareRoot}/media
    '';
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    winbindd.enable = false;
    settings = {
      global = {
        "server string" = "nixos-fileserver";
        "workgroup" = "WORKGROUP";
        "map to guest" = "Never";
      };

      shared = mkWritableShare "${shareRoot}/shared" "General shared storage";
      media = mkWritableShare "${shareRoot}/media" "Media library";
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
