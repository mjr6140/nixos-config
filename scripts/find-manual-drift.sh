#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: find-manual-drift.sh [--host HOST] [--days DAYS] [--flake PATH] [--home PATH] [--include-local-share]

Checks for likely manual drift between your running system and nixos-config:
  1) Running system revision vs repo HEAD
  2) Closure diff: /run/current-system vs freshly built toplevel
  3) Recently modified files in /etc
  4) Recently modified config-ish files in /home

Options:
  --host HOST    NixOS host name in flake output (default: current hostname)
  --days DAYS    Look back window for /etc edits (default: 14)
  --flake PATH   Flake path (default: .)
  --home PATH    Home directory to scan (default: $HOME)
  --include-local-share
                 Also scan ~/.local/share (noisier; may include app state)
  -h, --help     Show this help
EOF
}

HOST="$(hostname)"
DAYS=14
FLAKE="."
HOME_DIR="${HOME}"
INCLUDE_LOCAL_SHARE=0

while (($# > 0)); do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    --flake)
      FLAKE="$2"
      shift 2
      ;;
    --home)
      HOME_DIR="$2"
      shift 2
      ;;
    --include-local-share)
      INCLUDE_LOCAL_SHARE=1
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

echo "== Drift Check =="
echo "Date: $(date -Is)"
echo "Host: ${HOST}"
echo "Flake: ${FLAKE}"
echo "Window: last ${DAYS} day(s)"
echo "Home scan: ${HOME_DIR}"
if [[ "${INCLUDE_LOCAL_SHARE}" -eq 1 ]]; then
  echo "Home scope: .config + dotfiles + .local/share"
else
  echo "Home scope: .config + dotfiles"
fi
echo

echo "== 1) Config revision check =="
running_rev=""
if command -v nixos-version >/dev/null 2>&1; then
  if command -v jq >/dev/null 2>&1; then
    running_rev="$(nixos-version --json | jq -r '.configurationRevision // empty')"
  else
    running_rev="$(nixos-version --json | sed -n 's/.*"configurationRevision":"\([^"]*\)".*/\1/p')"
  fi
fi

repo_rev="$(git -C "${FLAKE}" rev-parse HEAD)"
echo "Running revision: ${running_rev:-<unknown>}"
echo "Repo HEAD:        ${repo_rev}"
if [[ -n "${running_rev}" && "${running_rev}" == "${repo_rev}" ]]; then
  echo "Status: running system revision matches repo HEAD."
else
  echo "Status: mismatch or unknown running revision."
fi
echo

echo "== 2) Closure diff check =="
target="${FLAKE}#nixosConfigurations.${HOST}.config.system.build.toplevel"
echo "Building ${target} ..."
build_err="$(mktemp)"
trap 'rm -f "${build_err}"' EXIT
if build_out="$(nix build "${target}" --no-link --print-out-paths 2>"${build_err}")"; then
  echo "Built toplevel: ${build_out}"
  echo "Diff against /run/current-system:"
  nix store diff-closures /run/current-system "${build_out}" || true
else
  echo "Build failed; skipping closure diff."
  sed 's/^/  /' "${build_err}" || true
fi
echo

echo "== 3) Recently modified /etc files =="
find_cmd=(find /etc -xdev -type f -mtime "-${DAYS}" -print)

if command -v sudo >/dev/null 2>&1; then
  if sudo -n true >/dev/null 2>&1; then
    sudo "${find_cmd[@]}"
  else
    echo "Note: sudo needs a password; re-run with sudo for full /etc visibility."
    "${find_cmd[@]}" 2>/dev/null || true
  fi
else
  "${find_cmd[@]}" 2>/dev/null || true
fi

echo
echo "== 4) Recently modified /home config files =="
if [[ ! -d "${HOME_DIR}" ]]; then
  echo "Home path does not exist: ${HOME_DIR}"
  exit 0
fi

echo "Managed symlinks (to /nix/store) under home:"
find "${HOME_DIR}" -xdev -type l -lname '/nix/store/*' 2>/dev/null | wc -l | sed 's/^/  count: /'
echo
echo "Recently modified unmanaged config files:"
max_results=200
results_file="$(mktemp)"
trap 'rm -f "${build_err}" "${results_file}"' EXIT

# 4a) dotfiles at home root
find "${HOME_DIR}" -maxdepth 1 -xdev \
  \( -type f -o -type l \) \
  -name '.*' \
  -mtime "-${DAYS}" \
  ! \( -type l -lname '/nix/store/*' \) \
  -print 2>/dev/null >>"${results_file}"

# 4b) ~/.config (excluding common volatile dirs)
if [[ -d "${HOME_DIR}/.config" ]]; then
  find "${HOME_DIR}/.config" -xdev \
    \( -path "${HOME_DIR}/.config/Code/Cache" -o \
       -path "${HOME_DIR}/.config/Code/CachedData" -o \
       -path "${HOME_DIR}/.config/google-chrome" -o \
       -path "${HOME_DIR}/.config/BraveSoftware" -o \
       -path '*/Cache' -o -path '*/Cache/*' -o \
       -path '*/GPUCache' -o -path '*/GPUCache/*' -o \
       -path '*/Code Cache' -o -path '*/Code Cache/*' -o \
       -path '*/logs' -o -path '*/logs/*' -o \
       -path '*/Local Storage' -o -path '*/Local Storage/*' -o \
       -path '*/Session Storage' -o -path '*/Session Storage/*' -o \
       -path '*/IndexedDB' -o -path '*/IndexedDB/*' -o \
       -path '*/Service Worker' -o -path '*/Service Worker/*' \) -prune -o \
    \( -type f -o -type l \) \
    -mtime "-${DAYS}" \
    ! \( -type l -lname '/nix/store/*' \) \
    -print 2>/dev/null >>"${results_file}"
fi

if [[ "${INCLUDE_LOCAL_SHARE}" -eq 1 ]]; then
  # 4c) optional ~/.local/share (high-noise, heavy pruning)
  if [[ -d "${HOME_DIR}/.local/share" ]]; then
    find "${HOME_DIR}/.local/share" -xdev \
      \( -path "${HOME_DIR}/.local/share/Steam" -o \
         -path "${HOME_DIR}/.local/share/Trash" -o \
         -path "${HOME_DIR}/.local/share/gvfs-metadata" -o \
         -path "${HOME_DIR}/.local/share/recently-used.xbel" -o \
         -path "${HOME_DIR}/.local/share/gnome-shell" -o \
         -path "${HOME_DIR}/.local/share/keyrings" \) -prune -o \
      \( -type f -o -type l \) \
      -mtime "-${DAYS}" \
      ! \( -type l -lname '/nix/store/*' \) \
      -print 2>/dev/null >>"${results_file}"
  fi
fi

sort -u "${results_file}" | head -n "${max_results}"
total_results="$(wc -l <"${results_file}" | tr -d '[:space:]')"
if [[ "${total_results}" -gt "${max_results}" ]]; then
  echo "  ... output truncated (${max_results}/${total_results})."
fi

echo "Note: listed files are recent and not symlinked to /nix/store."
