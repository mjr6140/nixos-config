{ config, lib, pkgs, ... }:

let
  curl = lib.getExe pkgs.curl;
  snapraid = lib.getExe pkgs.snapraid;
  healthchecksSecret = config.age.secrets.snapraid-healthchecks-env.path;

  mkSnapraidWrapper = name: command: urlVar:
    pkgs.writeShellScript "snapraid-${name}-healthchecks" ''
      set -u

      ping_url="''${${urlVar}:-}"

      ping() {
        suffix="$1"

        if [ -z "$ping_url" ]; then
          return 0
        fi

        ${curl} \
          --fail \
          --silent \
          --show-error \
          --max-time 10 \
          --retry 2 \
          "$ping_url$suffix" \
          >/dev/null || true
      }

      ping "/start"

      set +e
      ${command}
      status=$?
      set -e

      ping "/$status"
      exit "$status"
    '';

  syncWrapper = mkSnapraidWrapper "sync" "${snapraid} sync" "HC_SNAPRAID_SYNC_URL";
  scrubWrapper = mkSnapraidWrapper
    "scrub"
    "${snapraid} scrub -p ${toString config.services.snapraid.scrub.plan} -o ${toString config.services.snapraid.scrub.olderThan}"
    "HC_SNAPRAID_SCRUB_URL";
in
{
  age.identityPaths = [ "/var/lib/agenix/identity" ];

  age.secrets.snapraid-healthchecks-env = {
    file = ../../secrets/snapraid-healthchecks.env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/agenix 0700 root root - -"
  ];

  systemd.services.snapraid-sync = {
    # Keep SnapRAID running even if the healthchecks secret is not present yet.
    serviceConfig.EnvironmentFile = [ "-${healthchecksSecret}" ];
    # The upstream unit sets RestrictAddressFamilies=none, which blocks curl DNS/network.
    serviceConfig.RestrictAddressFamilies = lib.mkForce [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    serviceConfig.ExecStart = lib.mkForce syncWrapper;
  };

  systemd.services.snapraid-scrub = {
    # Keep SnapRAID running even if the healthchecks secret is not present yet.
    serviceConfig.EnvironmentFile = [ "-${healthchecksSecret}" ];
    # The upstream unit sets RestrictAddressFamilies=none, which blocks curl DNS/network.
    serviceConfig.RestrictAddressFamilies = lib.mkForce [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    serviceConfig.ExecStart = lib.mkForce scrubWrapper;
  };
}
