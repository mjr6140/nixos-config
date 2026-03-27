# System-wide packages for headless and server-oriented hosts.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
    direnv
    nix-direnv
    lm_sensors
    nvd
    wol
    restic
    borgbackup
    smartmontools
  ];
}
