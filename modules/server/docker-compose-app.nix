{ config, lib, pkgs, ... }:

let
  cfg = config.server.dockerComposeApps;

  renderInstance = name: instance:
    let
      composeDir = instance.composeDir;
      composeFile = "${composeDir}/compose.yaml";
      envFile = "${composeDir}/.env";
      composeFileSource =
        if instance.composeFileSource != null && instance.composeSpec != null then
          throw "dockerComposeApps.${name}: set exactly one of composeFileSource or composeSpec."
        else if instance.composeFileSource != null then
          instance.composeFileSource
        else if instance.composeSpec != null then
          (pkgs.formats.yaml { }).generate "${name}-compose.yaml" instance.composeSpec
        else
          throw "dockerComposeApps.${name}: set one of composeFileSource or composeSpec.";
      envDefaultsText = lib.generators.toKeyValue { } instance.envDefaults;
      envDefaultsFile = pkgs.writeText "${name}.env.defaults" envDefaultsText;
      dockerCmd = lib.getExe config.virtualisation.docker.package;
      composeCmd = "${dockerCmd} compose --project-name ${instance.projectName} --file ${composeFile}";
      presentSecretEnv =
        lib.filterAttrs (_envVar: secretName: builtins.hasAttr secretName config.age.secrets) instance.secretEnv;
      renderEnvScript = pkgs.writeShellScript "render-${name}-env" ''
        install -d -m 0755 ${composeDir}
        cp ${envDefaultsFile} ${envFile}
        ${lib.concatMapStringsSep "\n" (envVar:
          let secret = presentSecretEnv.${envVar}; in
          "printf '%s\\n' \"${envVar}=$(cat ${config.age.secrets.${secret}.path})\" >> ${envFile}"
        ) (builtins.attrNames presentSecretEnv)}
        chmod 0600 ${envFile}
      '';
      envServiceName = "${name}-env";
      composeServiceName = "${name}-compose";
    in
    {
      tmpfiles = [
        "d ${composeDir} 0755 root root - -"
        "L+ ${composeFile} - - - - ${composeFileSource}"
      ]
      ++ map (dir: "d ${dir} 0755 root root - -") instance.appdataDirs
      ++ instance.extraTmpfiles;

      systemdServices = {
        ${envServiceName} = {
          description = "Render ${instance.description} environment file";
          wantedBy = instance.wantedBy;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = toString renderEnvScript;
          };
        };

        ${composeServiceName} = {
          description = "${instance.description} via Docker Compose";
          after = [ "docker.service" "network-online.target" "${envServiceName}.service" ];
          wants = [ "network-online.target" ];
          requires = [ "docker.service" "${envServiceName}.service" ];
          wantedBy = instance.wantedBy;
          restartTriggers = [ composeFileSource ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            WorkingDirectory = composeDir;
            ExecStart = "${composeCmd} up -d --remove-orphans";
            ExecStop = "${composeCmd} down";
            TimeoutStartSec = 0;
          };
        };
      };
    };

  rendered = lib.mapAttrs renderInstance cfg.instances;
in
{
  options.server.dockerComposeApps = {
    instances = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
            default = name;
          };

          projectName = lib.mkOption {
            type = lib.types.str;
            default = name;
          };

          composeDir = lib.mkOption {
            type = lib.types.str;
            default = "/srv/compose/${name}";
          };

          composeFileSource = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
          };

          composeSpec = lib.mkOption {
            type = lib.types.nullOr lib.types.attrs;
            default = null;
          };

          envDefaults = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };

          secretEnv = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Map env var names to config.age.secrets names.";
          };

          appdataDirs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };

          extraTmpfiles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };

          wantedBy = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "multi-user.target" ];
          };

          firewall = {
            allowedTCPPorts = lib.mkOption {
              type = lib.types.listOf lib.types.port;
              default = [ ];
            };

            allowedUDPPorts = lib.mkOption {
              type = lib.types.listOf lib.types.port;
              default = [ ];
            };
          };
        };
      }));
    };
  };

  config = lib.mkIf (cfg.instances != { }) {
    systemd.tmpfiles.rules =
      lib.concatMap (instance: instance.tmpfiles) (builtins.attrValues rendered);

    systemd.services = lib.mkMerge (map (instance: instance.systemdServices) (builtins.attrValues rendered));

    networking.firewall.allowedTCPPorts =
      lib.mkAfter (lib.concatMap (instance: instance.firewall.allowedTCPPorts) (builtins.attrValues cfg.instances));

    networking.firewall.allowedUDPPorts =
      lib.mkAfter (lib.concatMap (instance: instance.firewall.allowedUDPPorts) (builtins.attrValues cfg.instances));
  };
}
