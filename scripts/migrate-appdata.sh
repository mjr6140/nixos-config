#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: migrate-appdata.sh [options]

Streams an appdata directory from a source host to a destination host over SSH.
This is intended for one-stack-at-a-time migrations such as:
  TrueNAS appdata -> mini PC /srv/appdata/<service>

The script can:
  1. stop the source stack/service
  2. stop the destination stack/service
  3. replace the destination appdata directory
  4. stream a tar archive directly from source to destination
  5. optionally chown the destination data
  6. optionally start the destination stack/service

Required:
  --source HOST          SSH target for the source, e.g. admin@truenas
  --source-path PATH     Absolute source path, e.g. /mnt/tank/apps/karakeep
  --dest HOST            SSH target for the destination, e.g. matt@nixos-minipc
  --dest-path PATH       Absolute destination path, e.g. /srv/appdata/karakeep

Optional:
  --stop-source-cmd CMD  Command to stop the source stack/service
  --stop-dest-cmd CMD    Command to stop the destination stack/service
  --start-dest-cmd CMD   Command to start the destination stack/service
  --chown USER:GROUP     Run chown -R on the destination path after transfer
  --replace              Remove the destination path before extracting
  --ssh-opt OPT          Extra SSH option; may be passed multiple times
  --dry-run              Print the plan without making changes
  -h, --help             Show this help

Example:
  scripts/migrate-appdata.sh \
    --source admin@truenas \
    --source-path /mnt/tank/apps/karakeep \
    --dest matt@nixos-minipc \
    --dest-path /srv/appdata/karakeep \
    --stop-source-cmd 'cd /mnt/tank/apps/karakeep && docker compose down' \
    --stop-dest-cmd 'sudo systemctl stop karakeep-compose' \
    --start-dest-cmd 'sudo systemctl start karakeep-compose' \
    --replace
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

quote_sq() {
  printf "'%s'" "${1//\'/\'\"\'\"\'}"
}

SOURCE_HOST=""
SOURCE_PATH=""
DEST_HOST=""
DEST_PATH=""
STOP_SOURCE_CMD=""
STOP_DEST_CMD=""
START_DEST_CMD=""
CHOWN_TARGET=""
REPLACE=0
DRY_RUN=0
SSH_OPTS=()

while (($# > 0)); do
  case "$1" in
    --source)
      SOURCE_HOST="$2"
      shift 2
      ;;
    --source-path)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --dest)
      DEST_HOST="$2"
      shift 2
      ;;
    --dest-path)
      DEST_PATH="$2"
      shift 2
      ;;
    --stop-source-cmd)
      STOP_SOURCE_CMD="$2"
      shift 2
      ;;
    --stop-dest-cmd)
      STOP_DEST_CMD="$2"
      shift 2
      ;;
    --start-dest-cmd)
      START_DEST_CMD="$2"
      shift 2
      ;;
    --chown)
      CHOWN_TARGET="$2"
      shift 2
      ;;
    --replace)
      REPLACE=1
      shift
      ;;
    --ssh-opt)
      SSH_OPTS+=("$2")
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$SOURCE_HOST" || -z "$SOURCE_PATH" || -z "$DEST_HOST" || -z "$DEST_PATH" ]]; then
  echo "Missing required arguments." >&2
  usage >&2
  exit 2
fi

require_cmd ssh
require_cmd tar
require_cmd dirname
require_cmd basename

SOURCE_PARENT="$(dirname "$SOURCE_PATH")"
SOURCE_BASENAME="$(basename "$SOURCE_PATH")"
DEST_PARENT="$(dirname "$DEST_PATH")"
DEST_BASENAME="$(basename "$DEST_PATH")"

run_remote() {
  local host="$1"
  local cmd="$2"

  echo "[$host] $cmd"
  if ((DRY_RUN)); then
    return 0
  fi

  ssh "${SSH_OPTS[@]}" "$host" "$cmd"
}

echo "== Appdata Migration =="
echo "Source:      ${SOURCE_HOST}:${SOURCE_PATH}"
echo "Destination: ${DEST_HOST}:${DEST_PATH}"
echo "Replace:     $([[ $REPLACE -eq 1 ]] && echo yes || echo no)"
echo "Chown:       ${CHOWN_TARGET:-<none>}"
echo

if [[ -n "$STOP_SOURCE_CMD" ]]; then
  run_remote "$SOURCE_HOST" "$STOP_SOURCE_CMD"
fi

if [[ -n "$STOP_DEST_CMD" ]]; then
  run_remote "$DEST_HOST" "$STOP_DEST_CMD"
fi

prepare_dest_cmd="sudo mkdir -p $(quote_sq "$DEST_PARENT")"
if ((REPLACE)); then
  prepare_dest_cmd+=" && sudo rm -rf $(quote_sq "$DEST_PATH")"
fi
run_remote "$DEST_HOST" "$prepare_dest_cmd"

echo "[transfer] ${SOURCE_HOST}:${SOURCE_PATH} -> ${DEST_HOST}:${DEST_PATH}"
if ((DRY_RUN)); then
  echo "[dry-run] skipping transfer"
else
  ssh "${SSH_OPTS[@]}" "$SOURCE_HOST" \
    "sudo tar --acls --xattrs --numeric-owner -C $(quote_sq "$SOURCE_PARENT") -cpf - $(quote_sq "$SOURCE_BASENAME")" \
    | ssh "${SSH_OPTS[@]}" "$DEST_HOST" \
      "sudo tar --acls --xattrs --numeric-owner -C $(quote_sq "$DEST_PARENT") -xpf -"
fi

if [[ -n "$CHOWN_TARGET" ]]; then
  run_remote "$DEST_HOST" "sudo chown -R $(quote_sq "$CHOWN_TARGET") $(quote_sq "$DEST_PATH")"
fi

if [[ -n "$START_DEST_CMD" ]]; then
  run_remote "$DEST_HOST" "$START_DEST_CMD"
fi

echo
echo "Migration complete."
echo "Recommended next step: validate the destination service before deleting the source data."
