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
    firefox
    eddie
    
    # Gaming
    lutris
    wowup-cf
    # Replaced by flatpak version
    # rusty-path-of-building
    xivlauncher
    faugus-launcher
    
    # Development Tools
    vim
    git
    direnv
    nix-direnv
    vscode
    
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
    llm-agents.codex
    
    # GNOME Tools
    gnome-tweaks
    gnome-extension-manager

    # Misc
    obsidian

    # Backup Tools
    restic
    borgbackup
  ];

  # Mikrotik Winbox 4 (Native Linux Version)
  programs.winbox = {
    enable = true;
    package = pkgs.winbox4;
    openFirewall = true;
  };
}
