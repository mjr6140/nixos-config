# Headless KVM/libvirt support for server-hosted virtual machines.
{ pkgs, ... }:

{
  virtualisation.libvirtd.enable = true;

  environment.systemPackages = with pkgs; [
    cloud-utils
    curl
    libvirt
    qemu_kvm
    "virt-install"
  ];

  users.users.matt.extraGroups = [ "libvirtd" ];
}
