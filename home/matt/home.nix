{ config, pkgs, lib, inputs, isVM, ... }:
let
  claudeDesktop =
    pkgs.callPackage
      "${inputs.claude-desktop}/pkgs/claude-desktop.nix"
      {
        patchy-cnb =
          inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.patchy-cnb;
        nodePackages = {
          inherit (pkgs) asar;
        };
      };

  claudeDesktopWithFhs = pkgs.buildFHSEnv {
    name = "claude-desktop";
    targetPkgs = pkgs': with pkgs'; [
      docker
      glibc
      openssl
      nodejs
      uv
    ];
    runScript = "${claudeDesktop}/bin/claude-desktop";
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${claudeDesktop}/share/applications/claude.desktop $out/share/applications/

      mkdir -p $out/share/icons
      cp -r ${claudeDesktop}/share/icons/* $out/share/icons/
    '';
  };
in
{
  imports = [ inputs.zen-browser.homeModules.twilight ];

  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity
    claudeDesktopWithFhs
    orca-slicer
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
        "firefox.desktop"
        "thunderbird.desktop"
        "steam.desktop"
      ];
    };
  };

  # Default Applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
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
        Mod+B hotkey-overlay-title="Open Firefox" { spawn "firefox"; }
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

  programs.mcp = {
    enable = true;
    servers.nixos = {
      command = lib.getExe pkgs.mcp-nixos;
    };
  };

  programs.codex = {
    enable = true;
    package = pkgs.llm-agents.codex;
    enableMcpIntegration = true;
  };

  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableSetDesktopBackground = true;
      DontCheckDefaultBrowser = true;
      OfferToSaveLogins = false;
      TranslateEnabled = false;
    };
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
        order = [
          "ddg"
          "google"
          "Nix Packages"
          "NixOS Wiki"
        ];
        engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ "@np" ];
            icon = "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          };
          "NixOS Wiki" = {
            urls = [
              {
                template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
              }
            ];
            definedAliases = [ "@nw" ];
            iconMapObj."16" = "https://wiki.nixos.org/favicon.ico";
          };
          google.metaData.alias = "@g";
          bing.metaData.hidden = true;
        };
      };

      settings = {
        "app.shield.optoutstudies.enabled" = false;
        "browser.aboutConfig.showWarning" = false;
        "browser.bookmarks.restore_default_bookmarks" = false;
        "browser.contentblocking.category" = "strict";
        "browser.ctrlTab.sortByRecentlyUsed" = true;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = true;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.system.showSponsored" = false;
        "browser.newtabpage.pinned" = [
          {
            label = "GitHub";
            url = "https://github.com/";
          }
          {
            label = "NixOS Search";
            url = "https://search.nixos.org/packages";
          }
          {
            label = "Home Manager";
            url = "https://nix-community.github.io/home-manager/";
          }
          {
            label = "Gmail";
            url = "https://mail.google.com/";
          }
        ];
        "browser.search.suggest.enabled" = true;
        "browser.startup.homepage" = "https://search.nixos.org/packages";
        "browser.startup.page" = 3;
        "browser.tabs.closeWindowWithLastTab" = false;
        "browser.toolbars.bookmarks.visibility" = "newtab";
        "extensions.autoDisableScopes" = 0;
        "media.eme.enabled" = true;
        "sidebar.revamp" = true;
        "signon.rememberSignons" = false;
      };
    };
  };

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = false;
    profiles.default.settings = {
      "zen.view.hide-window-controls" = false;
      "zen.folders.owned-tabs-in-folder" = true;
    };
  };

  programs.vscode = {
    enable = true;
    profiles.default = {
      userSettings = {
        "git.autofetch" = true;
        "[rust]" = {
          "editor.defaultFormatter" = "rust-lang.rust-analyzer";
        };
        "rust-analyzer.check.command" = "clippy";
        "rust-analyzer.cargo.features" = "all";
      };
      extensions = [
        pkgs.vscode-marketplace.github.copilot
        pkgs.vscode-marketplace."rust-lang"."rust-analyzer"
        pkgs.vscode-marketplace-universal.vadimcn."vscode-lldb"
        pkgs.vscode-marketplace.tamasfe."even-better-toml"
        pkgs.vscode-marketplace.github.copilot-chat
        pkgs.vscode-marketplace.donjayamanne.githistory
        pkgs.vscode-marketplace.openai.chatgpt
      ];
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

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    compaction = {
      auto = true;
      prune = true;
      reserved = 4000;
    };
    provider = {
      "llama.cpp" = {
        npm = "@ai-sdk/openai-compatible";
        name = "llama.cpp (local)";
        options = {
          baseURL = "http://127.0.0.1:8080/v1";
        };
        models = {
          "qwen3-coder" = {
            name = "Qwen3 Coder A3B (local)";
            limit = {
              context = 32768;
              output = 4096;
            };
          };
        };
      };
    };
    model = "llama.cpp/qwen3-coder";
    small_model = "llama.cpp/qwen3-coder";
  };
}
