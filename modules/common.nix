# Common system configuration shared across all hosts
# Includes: bootloader, locale, base networking, users, SSH, security
# hardening, and maintenance
{ config, pkgs, inputs, nixpkgsInput, ... }:

{
  # Bootloader (common settings)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Locale & Time
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Users
  users.users.matt = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
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
  # Security hardening
  security.sudo.wheelNeedsPassword = true;

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

    # Binary caches
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];

    # Trusted users for binary cache
    trusted-users = [ "root" "@wheel" ];
  };
  nix.registry.nixpkgs.flake = nixpkgsInput;
  nix.nixPath = [ "nixpkgs=${nixpkgsInput}" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Networking (NetworkManager)
  networking.networkmanager.enable = true;

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH
    allowedUDPPorts = [ ];
  };
}
