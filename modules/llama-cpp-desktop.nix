{ lib, pkgs, ... }:

let
  llamaCppCuda = (pkgs.llama-cpp.override {
    cudaSupport = true;
    blasSupport = true;
  }).overrideAttrs (oldAttrs: {
    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DGGML_NATIVE=ON"
    ];
    preConfigure = ''
      export NIX_ENFORCE_NO_NATIVE=0
      ${oldAttrs.preConfigure or ""}
    '';
  });
in
{
  environment.systemPackages = [
    llamaCppCuda
  ];

  networking.firewall.allowedTCPPorts = [ 8080 ];

  systemd.tmpfiles.rules = [
    "d /var/lib/llama.cpp 0750 llama-cpp llama-cpp -"
    "d /var/lib/llama.cpp/models 0750 llama-cpp llama-cpp -"
  ];

  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    home = "/var/lib/llama.cpp";
    createHome = false;
  };

  environment.etc."llama.cpp/README".text = ''
    llama.cpp is installed with CUDA support.

    1. Put one or more GGUF models under /var/lib/llama.cpp/models.
    2. Create /var/lib/llama.cpp/llama-server.env with at least:

       MODEL=/var/lib/llama.cpp/models/your-model.gguf

    Optional settings:
       HOST=0.0.0.0
       PORT=8080
       CTX_SIZE=32768
       BATCH_SIZE=2048
       UBATCH_SIZE=512
       THREADS=8
       N_GPU_LAYERS=-1
       ALIAS=local-llama

    3. Start the server:
       sudo systemctl start llama-cpp-server

    4. Enable it on boot:
       sudo systemctl enable llama-cpp-server

    The service listens on TCP 8080 by default.
  '';

  systemd.services.llama-cpp-server = {
    description = "llama.cpp OpenAI-compatible inference server";
    after = [ "network-online.target" "nvidia-persistenced.service" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/var/lib/llama.cpp/llama-server.env";
    serviceConfig = {
      Type = "simple";
      User = "llama-cpp";
      Group = "llama-cpp";
      WorkingDirectory = "/var/lib/llama.cpp";
      StateDirectory = "llama.cpp";
      Restart = "on-failure";
      RestartSec = "5s";
      EnvironmentFile = "-/var/lib/llama.cpp/llama-server.env";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/llama.cpp" ];
      RuntimeDirectory = "llama-cpp";
      ExecStart = lib.getExe (pkgs.writeShellScriptBin "llama-cpp-server" ''
        set -euo pipefail

        : "''${MODEL:?Set MODEL in /var/lib/llama.cpp/llama-server.env}"

        export HOST="''${HOST:-0.0.0.0}"
        export PORT="''${PORT:-8080}"
        export CTX_SIZE="''${CTX_SIZE:-32768}"
        export BATCH_SIZE="''${BATCH_SIZE:-2048}"
        export UBATCH_SIZE="''${UBATCH_SIZE:-512}"
        export THREADS="''${THREADS:-8}"
        export N_GPU_LAYERS="''${N_GPU_LAYERS:--1}"
        export ALIAS="''${ALIAS:-local-llama}"

        exec ${lib.getExe' llamaCppCuda "llama-server"} \
          --host "$HOST" \
          --port "$PORT" \
          --model "$MODEL" \
          --alias "$ALIAS" \
          --ctx-size "$CTX_SIZE" \
          --batch-size "$BATCH_SIZE" \
          --ubatch-size "$UBATCH_SIZE" \
          --threads "$THREADS" \
          --n-gpu-layers "$N_GPU_LAYERS"
      '');
    };
  };
}
