# Shared defaults for server-oriented hosts.
{ lib, ... }:

{
  services.openssh.settings.X11Forwarding = lib.mkDefault false;
}
