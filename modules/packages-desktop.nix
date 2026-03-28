# System-wide packages for desktop and desktop-like VM hosts.
{ pkgs, inputs, nixpkgsInput, ... }:

{
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
    opencode
    python3Packages.huggingface-hub
    ripgrep

    # Nix Tools
    nvd
    inputs.agenix.packages.${pkgs.system}.default

    # Niri deps
    alacritty
    fuzzel
    swaylock
    mako
    swayidle

    # Virtualization and Containerization
    distrobox
    distroshelf
    nfs-utils

    # Media
    vlc

    # LLM Agents
    llm-agents.codex

    # GNOME Tools
    gnome-tweaks
    gnome-extension-manager

    # Misc
    obsidian
    wol

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
