{ config, pkgs, inputs, ... }:

{
  # Imports
  imports = [ ./hardware-configuration.nix ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel (Standard for VM)
  boot.kernelPackages = pkgs.linuxPackages;

  # Networking
  networking.hostName = "nixos-vm";
  networking.networkmanager.enable = true;

  # Locale & Time
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

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

  # Graphics (Generic for VM)
  hardware.graphics.enable = true;
  # No Nvidia drivers here

  # KVM Guest Tools
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # XDG Portals
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Desktop & Login
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  programs.niri.enable = true;
  programs.dankMaterialShell.enable = true;

  # Virtualisation & Containers
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;

  # Users
  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker" ];
  };

  # System Tools
  environment.systemPackages = with pkgs; [
    brave
    thunderbird
    lutris
    # rusty-path-of-building
    # rusty-path-of-building # Might be heavy for VM, keeping it if user wants same environment
    vim
    git
    direnv
    nix-direnv
    vlc
    gnome-tweaks
    gnome-extension-manager
  ];

  # Hardware Services
  services.flatpak.enable = true;
  services.fwupd.enable = true;
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # Maintenance & Flakes
  services.btrfs.autoScrub.enable = true;
  services.fstrim.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.nix-ld.enable = true;

  system.stateVersion = "25.11";
}
