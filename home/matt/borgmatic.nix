{ config, pkgs, lib, ... }:

{
  programs.borgmatic = {
    enable = true;
    backups = {};
  };

  xdg.configFile."borgmatic.d/main.yaml".source = ./borgmatic.yaml;


  systemd.user.services.borgmatic = {
    Unit = {
      Description = "Borgmatic backup";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.borgmatic} --verbosity -1 --syslog-verbosity 1";
      # Restart = "on-failure"; 
    };
  };

  systemd.user.timers.borgmatic = {
    Unit = {
      Description = "Run borgmatic backup daily";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
