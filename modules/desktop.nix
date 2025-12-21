{ config, pkgs, ... }:

{
  # Desktop & Login
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  programs.niri.enable = true;
  programs.dankMaterialShell.enable = true;
}
