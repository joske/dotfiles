#!/usr/bin/env bash

set -euo pipefail

usage() {
	echo "Usage: $0 [-s session-name] <path> [path...]"
	echo "  First path must be a directory (used as working directory)."
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

PATHS=()
for arg in "$@"; do
	p=$(realpath "$arg")
	if [[ ! -e "$p" ]]; then
		echo "Error: '$p' does not exist"
		exit 1
	fi
	if [[ ! -r "$p" ]]; then
		echo "Error: '$p' is not readable"
		exit 1
	fi
	PATHS+=("$p")
done

if [[ ! -d "${PATHS[0]}" ]]; then
	echo "Error: first path '${PATHS[0]}' must be a directory"
	exit 1
fi

CLAUDE_ARGS=(--dangerously-skip-permissions)
if [[ -n "$NAME" ]]; then
	CLAUDE_ARGS+=(--resume "$NAME")
fi

if [[ ! -L "$HOME/.claude.json" ]]; then
	if [[ -f "$HOME/.claude.json" ]]; then
		if [[ -e "$HOME/.claude/.claude.json" ]]; then
			echo "Error: ~/.claude.json is a regular file but ~/.claude/.claude.json already exists; resolve manually"
			exit 1
		fi
		mv "$HOME/.claude.json" "$HOME/.claude/.claude.json"
		ln -s .claude/.claude.json "$HOME/.claude.json"
		echo "Migrated ~/.claude.json into ~/.claude/ and symlinked"
	elif [[ -e "$HOME/.claude/.claude.json" ]]; then
		ln -s .claude/.claude.json "$HOME/.claude.json"
		echo "Created ~/.claude.json symlink into ~/.claude/"
	fi
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
	--setenv CLAUDE_CONFIG_DIR "$HOME/.claude"
	--bind "$HOME/.local/state/claude" "$HOME/.local/state/claude"
	--bind "$HOME/.npm" "$HOME/.npm"
	--bind "$HOME/.cargo" "$HOME/.cargo"
	--bind "$HOME/.rustup" "$HOME/.rustup"
	--bind "$HOME/.cache" "$HOME/.cache"
	--bind "$HOME/.codex" "$HOME/.codex"
	--bind "$HOME/.docker" "$HOME/.docker"
	--bind /var/run/docker.sock /var/run/docker.sock
)

for p in "${PATHS[@]}"; do
	BWRAP_ARGS+=(--bind "$p" "$p")
done

BWRAP_ARGS+=(--chdir "${PATHS[0]}")

if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
	BWRAP_ARGS+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
	BWRAP_ARGS+=(--setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK")
fi

BWRAP_ARGS+=(--die-with-parent -- claude "${CLAUDE_ARGS[@]}")

exec bwrap "${BWRAP_ARGS[@]}"
