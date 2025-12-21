{ config, pkgs, inputs, isVM, ... }: {
  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    inputs.antigravity.packages.${pkgs.system}.google-antigravity
    # GNOME Extensions
    gnomeExtensions.dash-to-panel
    gnomeExtensions.appindicator
    gnomeExtensions.caffeine
    gnomeExtensions.gsconnect
    gnomeExtensions.hot-edge
    gnomeExtensions.logo-menu
  ] ++ (pkgs.lib.optionals isVM [ pkgs.spice-vdagent ]);

  # Enable and configure GNOME Extensions
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "dash-to-panel@jderose9.github.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "caffeine@patapon.info"
        "gsconnect@andyholmes.github.io"
        "hotedge@jonathan.jdoda.ca"
        "logomenu@aryan_k"
      ];
    };
  };

  # Use custom.kdl for personal tweaks; DMS manages config.kdl
  xdg.configFile."niri/custom.kdl".text = ''
    output "Beihai Century Joint Innovation Technology Co.,Ltd 34CHR Unknown" {
        mode "3440x1440@144.000"
        position x=0 y=0
        scale 1
        variable-refresh-rate
        focus-at-startup
    }

    binds {
        Mod+B hotkey-overlay-title="Open Firefox" { spawn "firefox"; }
        Mod+T hotkey-overlay-title="Open Terminal" { spawn "alacritty"; }
    }
  '' + (if isVM then ''
    
    spawn-at-startup "systemctl" "--user" "start" "spice-vdagent"
  '' else "");

  # Shell & Terminal Enhancements
  programs.bash.enable = true;
  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.eza.enable = true;
  programs.bat.enable = true;

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Matt Rickard";
      user.email = "mjr6140@gmail.com";
      filter."lfs" = {
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
      };
    };
  };

  # SPICE agent for VM auto-resize and clipboard
  systemd.user.services.spice-vdagent = pkgs.lib.mkIf isVM {
    Unit = {
      Description = "Spice session agent";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" "default.target" ];
    };
  };
}
