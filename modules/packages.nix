# System-wide packages shared across all hosts
# Add new applications here to make them available on both desktop and VM
{ config, pkgs, ... }:

{
  # System-wide packages shared across all hosts
  environment.systemPackages = with pkgs; [
    # Browsers & Communication
    brave
    thunderbird
    
    # Gaming
    lutris
    rusty-path-of-building
    
    # Development Tools
    vim
    git
    direnv
    nix-direnv
    
    # Media
    vlc
    
    # GNOME Tools
    gnome-tweaks
    gnome-extension-manager
  ];
}
