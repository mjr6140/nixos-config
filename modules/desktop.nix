# Desktop environment configuration
# Includes: GNOME, GDM, Niri, DankMaterialShell, and GNOME optimizations
{ config, pkgs, ... }:

{
  # Desktop & Login
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;  # Ensure Wayland is used
  services.desktopManager.gnome.enable = true;
  programs.niri.enable = true;
  programs.dankMaterialShell.enable = true;

  # GNOME configuration
  services.gnome = {
    gnome-keyring.enable = true;
    gnome-browser-connector.enable = true;
  };

  # Exclude unwanted GNOME apps
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany  # GNOME Web
    geary     # Email client (using Thunderbird)
  ];

  # XDG Desktop Portal configuration
  xdg.portal.config.common.default = "*";

  # Gaming (shared across all desktop-like hosts)
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # Flatpak & Flathub
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Install Path of Building automatically
  systemd.services.flatpak-install-pob = {
    wantedBy = [ "multi-user.target" ];
    after = [ "flatpak-repo.service" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak install -y flathub community.pathofbuilding.PathOfBuilding
    '';
    # Only run if not already installed
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
