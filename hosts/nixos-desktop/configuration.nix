{ config, pkgs, inputs, ... }:

{
  # Imports
  imports = [ ./hardware-configuration.nix ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel Optimization (CachyOS)
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linuxPackages_cachyos;
  
  nixpkgs.config.allowUnfree = true;

  # Networking
  networking.hostName = "nixos-desktop";
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

  # Graphics & Nvidia
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
  };
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

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

  # Gaming
  programs.steam.enable = true;
  programs.gamemode.enable = true;

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
  nix.settings = {
    substituters = [ "https://nixos-cachyos-kernel.cachix.org" ];
    trusted-public-keys = [ "nixos-cachyos-kernel.cachix.org-1:9Uf4shEitU6p61+nUuW4/V9qVxlYkH9YJbe1KwiI53M=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.nix-ld.enable = true;

  system.stateVersion = "25.11";

  # Allow unfree for this evaluation (redundant but safe)
  nixpkgs.config.allowUnfreePredicate = (_: true);
}
