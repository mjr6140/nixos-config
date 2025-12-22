{ config, pkgs, inputs, isVM, ... }: {
  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity
    (pkgs.callPackage ./qidi-studio.nix {})
  ] ++ (pkgs.lib.optionals isVM [ pkgs.spice-vdagent ]);

  # GNOME Extensions - installed and configured
  programs.gnome-shell = {
    enable = true;
    extensions = [
      { package = pkgs.gnomeExtensions.dash-to-panel; }
      { package = pkgs.gnomeExtensions.appindicator; }
      { package = pkgs.gnomeExtensions.caffeine; }
      { package = pkgs.gnomeExtensions.gsconnect; }
      { package = pkgs.gnomeExtensions.hot-edge; }
      # { package = pkgs.gnomeExtensions.logo-menu; }  # Uncomment if needed
    ];
  };

  # Legacy dconf settings (kept for compatibility)
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "dash-to-panel@jderose9.github.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "caffeine@patapon.info"
        "gsconnect@andyholmes.github.io"
        "hotedge@jonathan.jdoda.ca"
        # "logomenu@aryan_k"
      ];
    };
  };

  # Default Applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
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
        Mod+B hotkey-overlay-title="Open Brave" { spawn "brave"; }
        Mod+T hotkey-overlay-title="Open Terminal" { spawn "alacritty"; }
    }
  '';

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
    };
  };

  # SPICE agent for VM auto-resize and clipboard
  systemd.user.services.spice-vdagent = pkgs.lib.mkIf isVM {
    Unit = {
      Description = "Spice session agent";
    };
    Service = {
      ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
      Restart = "always";
      RestartSec = "3s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
