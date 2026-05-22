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
	AGENT_CMD=(codex -a never -s danger-full-access)
	if [[ ! -z "$NAME" ]]; then
		AGENT_CMD+=(resume "$NAME")
	fi
elif [[ "$AGENT" == "gemini" ]]; then
	AGENT_CMD=(gemini -y)
	if [[ ! -z "$NAME" ]]; then
		AGENT_CMD+=(-r "$NAME")
	fi
elif [[ "$AGENT" == "opencode" ]]; then
	AGENT_CMD=(opencode)
	if [[ ! -z "$NAME" ]]; then
		AGENT_CMD+=(-s "$NAME")
	fi
elif [[ "$AGENT" == "claude" ]]; then
	AGENT_CMD=(claude --dangerously-skip-permissions)
	if [[ ! -z "$NAME" ]]; then
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
	--dev-bind /dev/dri /dev/dri
	--tmpfs /run
	--setenv XDG_RUNTIME_DIR "/run/user/$(id -u)"
	--ro-bind "$HOME" "$HOME/realhome"
	--dir "$HOME"
	--bind "$HOME/.claude" "$HOME/.claude"
	--setenv CLAUDE_CONFIG_DIR "$HOME/.claude"
	--setenv GIT_SSH_COMMAND "ssh -F /dev/null"
)

function maybe_bind() {
	NAME=$1
	if [ -e "$NAME" ]; then
		BWRAP_ARGS+=(--bind "$NAME" "$NAME")
	fi
}

function maybe_ro_bind() {
	NAME=$1
	if [ -e "$NAME" ]; then
		BWRAP_ARGS+=(--ro-bind "$NAME" "$NAME")
	fi
}

maybe_ro_bind "/run/systemd/resolve"
maybe_ro_bind "$HOME/.ssh"
maybe_ro_bind "$HOME/.config/gh"
maybe_ro_bind "$HOME/.gitconfig"
maybe_ro_bind "$HOME/Projects/dotfiles"
maybe_ro_bind "$HOME/Projects/dotfiles"
maybe_ro_bind "$HOME/.local/bin/claude"

maybe_bind "/dev/kvm"
maybe_bind "/run/user/$(id -u)"
maybe_bind "$HOME/.codex"
maybe_bind "$HOME/.e16"
maybe_bind "$HOME/.npm"
maybe_bind "$HOME/.cargo"
maybe_bind "$HOME/.rustup"
maybe_bind "$HOME/.cache"
maybe_bind "$HOME/.Xauthority"
maybe_bind "$HOME/.docker"
maybe_bind "$HOME/.gemini"
maybe_bind "/var/run/docker.sock"
maybe_bind "$HOME/.local/share/claude"
maybe_bind "$HOME/.local/state/claude"
maybe_bind "$HOME/.config/opencode"
maybe_bind "$HOME/.local/share/opencode"
maybe_bind "$HOME/.local/state/opencode"
maybe_bind "/tmp/.X11-unix"
maybe_bind "/tmp/.XIM-unix"
maybe_bind "/tmp/.ICE-unix"
maybe_bind "/tmp/.font-unix"

for p in "${PATHS[@]}"; do
	BWRAP_ARGS+=(--bind "$p" "$p")
done

BWRAP_ARGS+=(--chdir "${PATHS[0]}")

# if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
# 	BWRAP_ARGS+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
# 	BWRAP_ARGS+=(--setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK")
# fi

BWRAP_ARGS+=(--die-with-parent -- "${AGENT_CMD[@]}")

exec bwrap "${BWRAP_ARGS[@]}"
