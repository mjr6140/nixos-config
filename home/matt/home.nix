{ config, pkgs, lib, inputs, isVM, ... }: {
  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-with-fhs
    (pkgs.callPackage ./qidi-studio.nix { })
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
    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close";
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      favorite-apps = [
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
        "brave-browser.desktop"
        "thunderbird.desktop"
        "steam.desktop"
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

  # Hide duplicate Brave desktop file (both files point to same binary)
  xdg.dataFile."applications/com.brave.Browser.desktop".text = ''[Desktop Entry]
Type=Application
Hidden=true
'';

  # Ensure Niri loads custom.kdl (without overwriting existing config.kdl)
  home.activation.niriIncludeCustom = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="${config.xdg.configHome}/niri/config.kdl"
    mkdir -p "$(dirname "$cfg")"
    if [ ! -f "$cfg" ]; then
      printf '%s\n\ninclude "custom.kdl"\n' "// Managed by Home Manager" > "$cfg"
    elif ! grep -q '^include \"custom\.kdl\"' "$cfg"; then
      printf '\ninclude "custom.kdl"\n' >> "$cfg"
    fi
  '';

  # Use custom.kdl for personal tweaks; DMS manages config.kdl
  xdg.configFile."niri/custom.kdl".text = ''
    spawn-at-startup "dms" "run"
    spawn-at-startup "wl-paste" "--watch" "cliphist" "store"

    # Needed to add to get cursor working: https://github.com/YaLTeR/niri/issues/2339
    cursor {
        xcursor-theme "Adwaita"
        xcursor-size 24
    }

    output "Beihai Century Joint Innovation Technology Co.,Ltd 34CHR Unknown" {
        mode "3440x1440@144.000"
        position x=0 y=0
        scale 1
        variable-refresh-rate
        focus-at-startup
    }

    binds {
        Mod+Space hotkey-overlay-title="Toggle Application Launcher" { spawn "dms" "ipc" "spotlight" "toggle"; }
        Mod+N hotkey-overlay-title="Toggle Notification Center" { spawn "dms" "ipc" "notifications" "toggle"; }
        Mod+Comma hotkey-overlay-title="Toggle Settings" { spawn "dms" "ipc" "settings" "toggle"; }
        Mod+P hotkey-overlay-title="Toggle Notepad" { spawn "dms" "ipc" "notepad" "toggle"; }
        Super+Alt+L hotkey-overlay-title="Toggle Lock Screen" { spawn "dms" "ipc" "lock" "lock"; }
        Mod+X hotkey-overlay-title="Toggle Power Menu" { spawn "dms" "ipc" "powermenu" "toggle"; }
        XF86AudioRaiseVolume allow-when-locked=true { spawn "dms" "ipc" "audio" "increment" "3"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "dms" "ipc" "audio" "decrement" "3"; }
        XF86AudioMute allow-when-locked=true { spawn "dms" "ipc" "audio" "mute"; }
        XF86AudioMicMute allow-when-locked=true { spawn "dms" "ipc" "audio" "micmute"; }
        Mod+Alt+N allow-when-locked=true hotkey-overlay-title="Toggle Night Mode" { spawn "dms" "ipc" "night" "toggle"; }
        Mod+M hotkey-overlay-title="Toggle Process List" { spawn "dms" "ipc" "processlist" "toggle"; }
        Mod+V hotkey-overlay-title="Toggle Clipboard Manager" { spawn "dms" "ipc" "clipboard" "toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "dms" "ipc" "brightness" "increment" "5" ""; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "dms" "ipc" "brightness" "decrement" "5" ""; }
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
