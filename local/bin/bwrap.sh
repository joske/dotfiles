#!/usr/bin/env bash

set -euo pipefail

usage() {
	echo "Usage: $0 [-d] [-s session-name] [-a agent] <path> [path...]"
	echo "  First path must be a directory (used as working directory)."
	echo "  -a agent: 'claude' (default) or 'codex'"
	echo "  -d: run bash instead of the selected agent for debugging"
	exit 1
}

NAME=""
AGENT="claude"
DEBUG=0
while true; do
	if [[ "${1:-}" == "-d" ]]; then
		DEBUG=1
		shift
	elif [[ "${1:-}" == "-s" ]]; then
		[[ $# -ge 2 ]] || usage
		NAME="$2"
		shift 2
	elif [[ "${1:-}" == "-a" ]]; then
		[[ $# -ge 2 ]] || usage
		AGENT="$2"
		shift 2
	else
		break
	fi
done

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

if [[ "$DEBUG" -eq 1 ]]; then
	AGENT_CMD=(bash)
elif [[ "$AGENT" == "codex" ]]; then
	AGENT_CMD=(codex -a never)
	if [[ -n "$NAME" ]]; then
		AGENT_CMD+=(resume "$NAME")
	fi
elif [[ "$AGENT" == "gemini" ]]; then
	AGENT_CMD=(gemini -y)
	if [[ -n "$NAME" ]]; then
		AGENT_CMD+=(-r "$NAME")
	fi
elif [[ "$AGENT" == "opencode" ]]; then
	AGENT_CMD=(opencode)
	if [[ -n "$NAME" ]]; then
		AGENT_CMD+=(-s "$NAME")
	fi
elif [[ "$AGENT" == "claude" ]]; then
	AGENT_CMD=(claude --dangerously-skip-permissions --resume)
	if [[ -n "$NAME" ]]; then
		AGENT_CMD+=(--resume "$NAME")
	fi
else
	echo "Error: unknown agent '$AGENT' (supported: claude, codex)"
	exit 1
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
	--ro-bind /boot /boot
	--ro-bind /usr /usr
	--symlink usr/bin /bin
	--symlink usr/lib /lib
	--symlink usr/lib64 /lib64
	--ro-bind /etc /etc
	--dir /tmp
	--dir /var
	--ro-bind /opt /opt
	--ro-bind /sys /sys
	--proc /proc
	--dev /dev
	--bind /dev/kvm /dev/kvm
	--bind /dev/dri /dev/dri
	--tmpfs /run
	--bind "/run/user/$(id -u)" "/run/user/$(id -u)"
	--setenv XDG_RUNTIME_DIR "/run/user/$(id -u)"
	--ro-bind "$HOME" "$HOME/realhome"
	--dir "$HOME"
	--bind "$HOME/.claude" "$HOME/.claude"
	--setenv CLAUDE_CONFIG_DIR "$HOME/.claude"
	--bind "$HOME/.npm" "$HOME/.npm"
	--bind "$HOME/.e16" "$HOME/.e16"
	--bind "$HOME/.cargo" "$HOME/.cargo"
	--bind "$HOME/.rustup" "$HOME/.rustup"
	--bind "$HOME/.cache" "$HOME/.cache"
	--bind "$HOME/.codex" "$HOME/.codex"
	--bind "$HOME/.config/opencode/" "$HOME/.config/opencode/"
	--bind "$HOME/.local/share/opencode/" "$HOME/.local/share/opencode/"
	--bind "$HOME/.local/state/opencode/" "$HOME/.local/state/opencode/"
	--bind "$HOME/.gemini" "$HOME/.gemini"
	--bind "$HOME/.docker" "$HOME/.docker"
	--bind "/tmp/.X11-unix" "/tmp/.X11-unix"
	--bind "/tmp/.ICE-unix" "/tmp/.ICE-unix"
	--bind "/tmp/.font-unix" "/tmp/.font-unix"
	--bind "/tmp/.XIM-unix" "/tmp/.XIM-unix"
)

if [ -e /var/run/docker.sock ]; then
	BWRAP_ARGS+=(--bind /var/run/docker.sock /var/run/docker.sock)
fi

if [ -e "$HOME/.local/share/claude" ]; then
	BWRAP_ARGS+=(--bind "$HOME/.local/share/claude" "$HOME/.local/share/claude")
fi

if [ -e "$HOME/.local/state/claude" ]; then
	BWRAP_ARGS+=(--bind "$HOME/.local/state/claude" "$HOME/.local/state/claude")
fi

if [ -e "$HOME/.local/bin/claude" ]; then
	BWRAP_ARGS+=(--ro-bind "$HOME/.local/bin/claude" "$HOME/.local/bin/claude")
fi

for p in "${PATHS[@]}"; do
	BWRAP_ARGS+=(--bind "$p" "$p")
done

BWRAP_ARGS+=(--chdir "${PATHS[0]}")

if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
	BWRAP_ARGS+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
	BWRAP_ARGS+=(--setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK")
fi

BWRAP_ARGS+=(--die-with-parent -- "${AGENT_CMD[@]}")

exec bwrap "${BWRAP_ARGS[@]}"
