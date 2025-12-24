# System-wide packages shared across all hosts
# Add new applications here to make them available on both desktop and VM
{ config, pkgs, ... }:

{
  # System-wide packages shared across all hosts
  environment.systemPackages = with pkgs; [
    # Browsers & Communication
    brave
    thunderbird
    discord-ptb
    
    # Gaming
    lutris
    # Replaced by flatpak version
    # rusty-path-of-building
    
    # Development Tools
    vim
    git
    direnv
    nix-direnv
    
    # Nix Tools
    nvd

    # Niri deps
    alacritty
    fuzzel 
    swaylock 
    mako 
    swayidle    

    # Virtualization and Containerization
    distrobox
    distroshelf
    
    # Media
    vlc
    
    # LLM Agents
    codex
    
    # GNOME Tools
    gnome-tweaks
    gnome-extension-manager

    # Misc
    obsidian
  ];

  # Mikrotik Winbox 4 (Native Linux Version)
  programs.winbox = {
    enable = true;
    package = pkgs.winbox4;
    openFirewall = true;
  };
}
