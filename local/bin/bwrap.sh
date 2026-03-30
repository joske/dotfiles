#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <project-dir> [session-name]"
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

DIR=$(realpath "$1")
NAME=${2:-}

if [[ ! -d "$DIR" ]]; then
  echo "Error: '$DIR' is not a directory"
  exit 1
fi

if [[ ! -r "$DIR" ]]; then
  echo "Error: '$DIR' is not readable"
  exit 1
fi

CLAUDE_ARGS=(--dangerously-skip-permissions)
if [[ -n "$NAME" ]]; then
  CLAUDE_ARGS+=(--resume "$NAME")
fi

exec bwrap \
  --ro-bind /usr /usr \
  --symlink usr/bin /bin \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind /etc /etc \
  --dir /tmp \
  --dir /var \
  --proc /proc \
  --dev /dev \
  --tmpfs /run \
  --dir "/run/user/$(id -u)" \
  --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)" \
  --ro-bind "$HOME" "$HOME" \
  --bind "$HOME/.claude" "$HOME/.claude" \
  --bind "$HOME/.claude.json" "$HOME/.claude.json" \
  --bind "$HOME/.local/state/claude" "$HOME/.local/state/claude" \
  --bind "$HOME/.npm" "$HOME/.npm" \
  --bind "$HOME/.cargo" "$HOME/.cargo" \
  --bind "$HOME/.rustup" "$HOME/.rustup" \
  --bind "$HOME/.cache" "$HOME/.cache" \
  --bind "$DIR" "$DIR" \
  --chdir "$DIR" \
  ${SSH_AUTH_SOCK:+--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK"} \
  ${SSH_AUTH_SOCK:+--setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK"} \
  --die-with-parent \
  -- claude "${CLAUDE_ARGS[@]}"
