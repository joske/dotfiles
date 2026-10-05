#!/usr/bin/env bash

set -euo pipefail

usage() {
	echo "Usage: $0 [-d] [-s session-name] [-a agent] [-o arg]... <path> [path...]"
	echo "  First path must be a directory (used as working directory)."
	echo "  -a agent: 'claude' (default) or 'codex', 'opencode', 'omp', 'gemini'"
	echo "  -d: run bash instead of the selected agent for debugging"
	echo "  -o arg: extra argument appended to the agent command, may be"
	echo "          repeated; order of -o flags is preserved"
	exit 1
}

SESSION_NAME=""
AGENT="claude"
DEBUG=0
AGENT_EXTRA=()

# ARGS parsing
while true; do
	if [[ "${1:-}" == "-d" ]]; then
		DEBUG=1
		shift
	elif [[ "${1:-}" == "-s" ]]; then
		[[ $# -ge 2 ]] || usage
		SESSION_NAME="$2"
		shift 2
	elif [[ "${1:-}" == "-a" ]]; then
		[[ $# -ge 2 ]] || usage
		AGENT="$2"
		shift 2
	elif [[ "${1:-}" == "-o" ]]; then
		[[ $# -ge 2 ]] || usage
		AGENT_EXTRA+=("$2")
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
	AGENT_CMD=(codex --no-daemon -a never -s danger-full-access --no-alt-screen)
	if [[ ! -z "$SESSION_NAME" ]]; then
		AGENT_CMD+=(resume "$SESSION_NAME")
	fi
elif [[ "$AGENT" == "gemini" ]]; then
	AGENT_CMD=(gemini -y)
	if [[ ! -z "$SESSION_NAME" ]]; then
		AGENT_CMD+=(-r "$SESSION_NAME")
	fi
elif [[ "$AGENT" == "opencode" ]]; then
	AGENT_CMD=(opencode)
	if [[ ! -z "$SESSION_NAME" ]]; then
		AGENT_CMD+=(-s "$SESSION_NAME")
	fi
elif [[ "$AGENT" == "omp" ]]; then
	AGENT_CMD=(omp)
	if [[ ! -z "$SESSION_NAME" ]]; then
		AGENT_CMD+=(--resume="$SESSION_NAME")
	fi
elif [[ "$AGENT" == "claude" ]]; then
	AGENT_CMD=(claude --dangerously-skip-permissions)
	if [[ ! -z "$SESSION_NAME" ]]; then
		AGENT_CMD+=(--resume "$SESSION_NAME")
	fi
else
	echo "Error: unknown agent '$AGENT' (supported: claude, codex)"
	exit 1
fi

AGENT_CMD+=("${AGENT_EXTRA[@]}")

# --bind only supports folders, but .claude.json lives directly in $HOME, and we don't want to give rw to $HOME
# so move it inside of ~/.claude, symlink and tell claude about this using CLAUDE_CONFIG_DIR
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
	--dir /tmp
	--proc /proc
	--dev /dev
	--tmpfs /run
	--dir "$HOME"
	--setenv XDG_RUNTIME_DIR "/run/user/$(id -u)"
	--setenv CLAUDE_CONFIG_DIR "$HOME/.claude"
	--setenv GIT_SSH_COMMAND "ssh -F /dev/null"
	--setenv RUSTC_WRAPPER "''"
)

function maybe_dev_bind() {
	NAME=$1
	if [ -e "$NAME" ]; then
		BWRAP_ARGS+=(--dev-bind "$NAME" "$NAME")
	fi
}

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

function symlink() {
	NAME=$1
	LINK=$2
	BWRAP_ARGS+=(--symlink "$NAME" "$LINK")
}

maybe_ro_bind /boot
maybe_ro_bind /usr
maybe_ro_bind /etc
maybe_ro_bind /opt
maybe_ro_bind /sys
maybe_ro_bind /var

symlink usr/bin /bin
symlink usr/lib /lib
symlink usr/lib64 /lib64

# the below dev mounts are for yserver testing
maybe_dev_bind "/dev/dri"
maybe_dev_bind "/dev/kvm"
maybe_dev_bind "/dev/udmabuf"

maybe_ro_bind "/run/systemd/resolve"
maybe_ro_bind "$HOME/.ssh/id_ed25519.pub"
maybe_ro_bind "$HOME/.ssh/known_hosts"
maybe_ro_bind "$HOME/.config/gh"
maybe_ro_bind "$HOME/.config/git/allowed_signers"
maybe_ro_bind "$HOME/.gitconfig"
maybe_ro_bind "$HOME/.risc0"

maybe_bind "/run/user/$(id -u)"
maybe_bind "$HOME/.codex"
maybe_bind "$HOME/.e16"
maybe_bind "$HOME/.npm"
maybe_bind "$HOME/.cargo"
maybe_bind "$HOME/.rustup"
maybe_bind "$HOME/.cache"
maybe_bind "$HOME/.Xauthority"
maybe_bind "$HOME/.gemini"
maybe_bind "$HOME/.claude"
maybe_bind "$HOME/Projects/dotfiles/claude/" # the above is a symlink to this
maybe_bind "$HOME/.local/bin/claude"
maybe_bind "$HOME/.local/share/claude"
maybe_bind "$HOME/.local/state/claude"
maybe_bind "$HOME/.omp"
maybe_bind "$HOME/.config/omp"
maybe_bind "$HOME/.config/opencode"
maybe_bind "$HOME/.local/share/opencode"
maybe_bind "$HOME/.local/state/opencode"
maybe_bind "/tmp/.X11-unix"
maybe_bind "/tmp/.XIM-unix"
maybe_bind "/tmp/.ICE-unix"
maybe_bind "/tmp/.font-unix"
maybe_bind "/tmp/tmux-$(id -u)"

# now bind all argument paths
for p in "${PATHS[@]}"; do
	BWRAP_ARGS+=(--bind "$p" "$p")
done

BWRAP_ARGS+=(--chdir "${PATHS[0]}")

# pass through SSH agent
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
	BWRAP_ARGS+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
	BWRAP_ARGS+=(--setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK")
fi

BWRAP_ARGS+=(--die-with-parent -- "${AGENT_CMD[@]}")

if [ "$DEBUG" = "1" ]; then
	echo "ARGS: ${BWRAP_ARGS[*]}"
fi

exec bwrap "${BWRAP_ARGS[@]}"
