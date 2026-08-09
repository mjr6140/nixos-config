# Desktop environment configuration
# Includes: GNOME, GDM, Niri, desktop services, desktop fonts, and
# workstation-specific overlays
{ config, lib, pkgs, inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.vscode-extensions.overlays.default
    inputs.llm-agents.overlays.shared-nixpkgs
    (import ../overlays/aioboto3-fix.nix)
    (import ../overlays/openldap-fix.nix)
  ];

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    fira-code
    fira-code-symbols
    jetbrains-mono
  ];
  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrains Mono" ];
    sansSerif = [ "Noto Sans" ];
    serif = [ "Noto Serif" ];
  };

  # Graphics (basic)
  hardware.graphics.enable = true;

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Desktop & Login
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  programs.niri.enable = true;
  programs.dank-material-shell.enable = true;

  # GNOME configuration
  services.gnome = {
    gnome-keyring.enable = true;
    gnome-browser-connector.enable = true;
  };

  # XDG Portals
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = "*";
  };

  # Exclude unwanted GNOME apps
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany # GNOME Web
    geary # Email client (using Thunderbird)
  ];

  # Virtualisation & Containers
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;

  users.users.matt.extraGroups = [ "libvirtd" "docker" ];

  # Hardware and desktop-adjacent services
  services.printing = {
    enable = true;
    browsed.enable = true;
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # resolvconf sends Avahi SIGHUP while refreshing DNS. If both start in
  # parallel, the signal can arrive before Avahi finishes initialization and
  # terminate it, which also prevents cups-browsed from starting.
  systemd.services.avahi-daemon.after = [ "resolvconf.service" ];
  systemd.services.avahi-daemon.serviceConfig.ExecStartPre =
    "+${lib.getExe' pkgs.coreutils "rm"} -f /run/avahi-daemon/pid";
  security.polkit.enable = true;
  security.rtkit.enable = true; # For PipeWire real-time priority
  programs.nix-ld.enable = true;

  # For GSConnect (GNOME phone integration)
  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 1714; to = 1764; }
  ];

  # Gaming (shared across all desktop-like hosts)
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # Flatpak applications and repositories
  services.flatpak.enable = true;
  systemd.services.flatpak-setup = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      flatpak remote-add --if-not-exists orion-beta https://flatpak.orionbrowser.com/orion-beta.flatpakrepo
      flatpak install --system --noninteractive --or-update flathub community.pathofbuilding.PathOfBuilding
      flatpak install --system --noninteractive --or-update orion-beta com.kagi.Orion
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };
}
