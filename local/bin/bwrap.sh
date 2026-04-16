#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [-s session-name] <dir> [dir...]"
  exit 1
}

NAME=""
if [[ "${1:-}" == "-s" ]]; then
  [[ $# -ge 2 ]] || usage
  NAME="$2"
  shift 2
fi

if [[ $# -lt 1 ]]; then
  usage
fi

DIRS=()
for arg in "$@"; do
  d=$(realpath "$arg")
  if [[ ! -d "$d" ]]; then
    echo "Error: '$d' is not a directory"
    exit 1
  fi
  if [[ ! -r "$d" ]]; then
    echo "Error: '$d' is not readable"
    exit 1
  fi
  DIRS+=("$d")
done

CLAUDE_ARGS=(--dangerously-skip-permissions)
if [[ -n "$NAME" ]]; then
  CLAUDE_ARGS+=(--resume "$NAME")
fi

BWRAP_ARGS=(
  --ro-bind /usr /usr
  --symlink usr/bin /bin
  --symlink usr/lib /lib
  --symlink usr/lib64 /lib64
  --ro-bind /etc /etc
  --dir /tmp
  --dir /var
  --proc /proc
  --dev /dev
  --tmpfs /run
  --dir "/run/user/$(id -u)"
  --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)"
  --ro-bind "$HOME" "$HOME"
  --bind "$HOME/.claude" "$HOME/.claude"
  --bind "$HOME/.claude.json" "$HOME/.claude.json"
  --bind "$HOME/.local/state/claude" "$HOME/.local/state/claude"
  --bind "$HOME/.npm" "$HOME/.npm"
  --bind "$HOME/.cargo" "$HOME/.cargo"
  --bind "$HOME/.rustup" "$HOME/.rustup"
  --bind "$HOME/.cache" "$HOME/.cache"
)

for d in "${DIRS[@]}"; do
  BWRAP_ARGS+=(--bind "$d" "$d")
done

BWRAP_ARGS+=(--chdir "${DIRS[0]}")

if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  BWRAP_ARGS+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
  BWRAP_ARGS+=(--setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK")
fi

BWRAP_ARGS+=(--die-with-parent -- claude "${CLAUDE_ARGS[@]}")

exec bwrap "${BWRAP_ARGS[@]}"
