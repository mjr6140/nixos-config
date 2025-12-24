# Common system configuration shared across all hosts
# Includes: bootloader, locale, fonts, audio, graphics, networking, users,
# virtualisation, hardware services, security hardening, and maintenance
{ config, pkgs, inputs, ... }:

{
  # Bootloader (common settings)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  # Graphics (basic)
  hardware.graphics.enable = true;

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

  # Virtualisation & Containers
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;

  # Users
  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker" ];
  };

  # SSH (secure configuration)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;  # Key-based auth only
    };
  };

  # Hardware Services
  services.fwupd.enable = true;
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # Security hardening
  security.sudo.wheelNeedsPassword = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;  # For PipeWire real-time priority

  # Kernel hardening
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "net.core.bpf_jit_harden" = 2;
  };

  # Zram swap for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Maintenance & Flakes
  services.btrfs.autoScrub.enable = true;
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
  
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Performance optimizations
    max-jobs = "auto";
    cores = 0;  # Use all available cores
    auto-optimise-store = true;

    # Trusted users for binary cache
    trusted-users = [ "root" "@wheel" ];
  };
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.nix-ld.enable = true;

  # Networking (NetworkManager)
  networking.networkmanager.enable = true;

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH
    allowedUDPPorts = [ ];
    # For GSConnect (GNOME phone integration)
    allowedTCPPortRanges = [ 
      { from = 1714; to = 1764; }
    ];
    allowedUDPPortRanges = [ 
      { from = 1714; to = 1764; }
    ];
  };
}
