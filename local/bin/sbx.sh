#!/usr/bin/env bash

# Persistent per-project bwrap sandbox. Each sandbox gets its own $HOME at
# $SBX_ROOT/<name>/home and /tmp at $SBX_ROOT/<name>/tmp;
# $SBX_ROOT/<name>/config is sourced on the host and is never visible inside
# the sandbox.

set -euo pipefail

usage() {
	cat <<EOF
Usage: $0 [-dN] [-p name] [-s session] [-a agent] [-o arg]... [path...] [-- cmd [args...]]
       $0 -L
  Paths are bound rw; the first must be a directory (used as working
  directory). They can be left out with -p if the sandbox config sets
  SBX_PATHS=(...).
  -- cmd: run cmd (e.g. fish) instead of the agent
  -a agent: 'claude' (default), 'codex', 'opencode', 'omp' or 'gemini'
  -d: debug: print bwrap args and run bash
  -N: no network (--unshare-net), same as SBX_NET=0 in config
  -p name: sandbox name (default: the -s session name if no paths are given,
           else <basename>-<sha256(realpath)[:8]> of first path)
  -L: list existing sandboxes and exit
  -s session: resume this agent session
  -o arg: extra argument appended to the agent command, may be repeated
Sandboxes live in \${SBX_ROOT:-\$HOME/.sandboxes}/<name>/{home,config}
EOF
	exit 1
}

SBX_ROOT="${SBX_ROOT:-$HOME/.sandboxes}"
SESSION_NAME=""
AGENT="claude"
DEBUG=0
AGENT_EXTRA=()
SBX_NAME=""
NO_NET=0
LIST=0

while getopts ":dNLp:s:a:o:" opt; do
	case "$opt" in
	d) DEBUG=1 ;;
	N) NO_NET=1 ;;
	L) LIST=1 ;;
	p) SBX_NAME="$OPTARG" ;;
	s) SESSION_NAME="$OPTARG" ;;
	a) AGENT="$OPTARG" ;;
	o) AGENT_EXTRA+=("$OPTARG") ;;
	*) usage ;;
	esac
done
# getopts eats a "--" right after the options; keep it so a command without
# paths ("sbx.sh -p foo -- fish") isn't taken for paths
END_OF_OPTS=0
if [[ $OPTIND -gt 1 && "${*:OPTIND-1:1}" == "--" ]]; then
	END_OF_OPTS=1
fi
shift $((OPTIND - 1))
if [[ "$END_OF_OPTS" -eq 1 ]]; then
	set -- -- "$@"
fi

if [[ "$LIST" -eq 1 ]]; then
	shopt -s nullglob
	dir_size() {
		if [[ -d "$1" ]]; then
			du -sh "$1" 2>/dev/null | cut -f1
		else
			echo "-"
		fi
	}
	printf '%-40s %8s %8s\n' NAME HOME TMP
	for d in "$SBX_ROOT"/*/; do
		printf '%-40s %8s %8s\n' "$(basename "$d")" "$(dir_size "$d/home")" "$(dir_size "$d/tmp")"
	done
	exit 0
fi

# resolve and check paths into PATHS; the first one must be a directory
function resolve_paths() {
	local arg p
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
}

# paths up to "--", the rest is the command
CLI_PATHS=()
USER_CMD=()
while [[ $# -gt 0 ]]; do
	if [[ "$1" == "--" ]]; then
		shift
		USER_CMD=("$@")
		break
	fi
	CLI_PATHS+=("$1")
	shift
done

PATHS=()
if [[ ${#CLI_PATHS[@]} -gt 0 ]]; then
	resolve_paths "${CLI_PATHS[@]}"
fi

if [[ -z "$SBX_NAME" && ${#PATHS[@]} -eq 0 && -n "$SESSION_NAME" ]]; then
	SBX_NAME="$SESSION_NAME" # "sbx.sh -s foo" = sandbox foo, resume session foo
fi
if [[ -z "$SBX_NAME" ]]; then
	[[ ${#PATHS[@]} -gt 0 ]] || usage
	hash=$(printf '%s' "${PATHS[0]}" | sha256sum | cut -c1-8)
	SBX_NAME="$(basename "${PATHS[0]}")-$hash"
fi
if [[ "$SBX_NAME" == */* || "$SBX_NAME" == "." || "$SBX_NAME" == ".." ]]; then
	echo "Error: invalid sandbox name '$SBX_NAME'"
	exit 1
fi

SBX="$SBX_ROOT/$SBX_NAME"
# a dir holding just a hand-written config counts as an existing sandbox
if [[ ${#PATHS[@]} -eq 0 && ! -d "$SBX" ]]; then
	echo "Error: sandbox '$SBX_NAME' doesn't exist; create it by passing its path(s)"
	exit 1
fi
if [[ ! -d "$SBX/home" ]]; then
	mkdir -p "$SBX/home"
	chmod 700 "$SBX" "$SBX/home"
	if [[ -f "$HOME/.gitconfig" ]]; then
		cp "$HOME/.gitconfig" "$SBX/home/.gitconfig"
	fi
	echo "Created sandbox '$SBX_NAME' at $SBX"
fi
# persistent per-sandbox /tmp (also created for sandboxes made before this existed)
if [[ ! -d "$SBX/tmp" ]]; then
	mkdir -p "$SBX/tmp"
	chmod 1777 "$SBX/tmp"
fi
# per-sandbox rw known_hosts, seeded from the host (also fills the empty
# mount-point file left behind by older versions that bound the host one)
if [[ ! -s "$SBX/home/.ssh/known_hosts" && -f "$HOME/.ssh/known_hosts" ]]; then
	mkdir -p "$SBX/home/.ssh"
	chmod 700 "$SBX/home/.ssh"
	# the old mount-point file is empty and 0444, so remove instead of overwrite
	rm -f "$SBX/home/.ssh/known_hosts"
	cp "$HOME/.ssh/known_hosts" "$SBX/home/.ssh/known_hosts"
fi

# per-project config (host side only, never bound into the sandbox)
# shellcheck disable=SC2034 # read indirectly via the OPTIN table
SBX_X11=0 SBX_GPU=0 SBX_KVM=0 SBX_UDMABUF=0
SBX_WAYLAND=0
SBX_PIPEWIRE=0
SBX_SSH_AGENT=0
SBX_NET=1
SBX_EXTRA_RO_BINDS=()
SBX_PATHS=()
if [[ -f "$SBX/config" ]]; then
	# shellcheck source=/dev/null
	source "$SBX/config"
fi
if [[ -n "${SBX_EXTRA_BINDS+x}" ]]; then
	echo "Error: SBX_EXTRA_BINDS was merged into SBX_PATHS; move its entries there in $SBX/config"
	exit 1
fi
# paths (all bound rw, first is the working dir): command line, else SBX_PATHS from config
if [[ ${#PATHS[@]} -eq 0 ]]; then
	if [[ ${#SBX_PATHS[@]} -eq 0 ]]; then
		echo "Error: no paths given and no SBX_PATHS in $SBX/config"
		echo "  add e.g.: SBX_PATHS=(\"\$HOME/Projects/$SBX_NAME\")"
		exit 1
	fi
	resolve_paths "${SBX_PATHS[@]}"
fi
[[ "$NO_NET" -eq 1 ]] && SBX_NET=0

if [[ "$DEBUG" -eq 1 ]]; then
	AGENT_CMD=(bash)
elif [[ ${#USER_CMD[@]} -gt 0 ]]; then
	AGENT_CMD=("${USER_CMD[@]}")
	# first fish start in this sandbox: seed it with a copy (not a bind) of the
	# host fish config; -L so symlinked files become real files
	if [[ "$(basename "${USER_CMD[0]}")" == "fish" && ! -e "$SBX/home/.config/fish" && -d "$HOME/.config/fish" ]]; then
		mkdir -p "$SBX/home/.config"
		cp -rL "$HOME/.config/fish" "$SBX/home/.config/fish"
		echo "Copied ~/.config/fish into sandbox '$SBX_NAME'"
	fi
else
	case "$AGENT" in
	codex)
		AGENT_CMD=(codex --no-daemon -a never -s danger-full-access --no-alt-screen)
		[[ -n "$SESSION_NAME" ]] && AGENT_CMD+=(resume "$SESSION_NAME")
		;;
	gemini)
		AGENT_CMD=(gemini -y)
		[[ -n "$SESSION_NAME" ]] && AGENT_CMD+=(-r "$SESSION_NAME")
		;;
	opencode)
		AGENT_CMD=(opencode)
		[[ -n "$SESSION_NAME" ]] && AGENT_CMD+=(-s "$SESSION_NAME")
		;;
	omp)
		AGENT_CMD=(omp)
		[[ -n "$SESSION_NAME" ]] && AGENT_CMD+=(--resume="$SESSION_NAME")
		;;
	claude)
		AGENT_CMD=(claude --dangerously-skip-permissions)
		[[ -n "$SESSION_NAME" ]] && AGENT_CMD+=(--resume "$SESSION_NAME")
		;;
	*)
		echo "Error: unknown agent '$AGENT' (supported: claude, codex, opencode, omp, gemini)"
		exit 1
		;;
	esac
	AGENT_CMD+=("${AGENT_EXTRA[@]}")
fi

# claude rewrites ~/.claude.json via write-temp-then-rename, which fails on a
# bind-mounted file (EBUSY), so the file itself can't be bound. Move it into
# ~/.claude (bound as a dir), symlink it, and point CLAUDE_CONFIG_DIR there.
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

RUNTIME_DIR="/run/user/$(id -u)"
HOST_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$RUNTIME_DIR}"

BWRAP_ARGS=(
	# must be first: everything below layers on top of the sandbox home
	--bind "$SBX/home" "$HOME"
	--bind "$SBX/tmp" /tmp # X11 socket binds below layer on top of this
	--proc /proc
	--dev /dev
	--tmpfs /run
	--perms 0700 --dir "$RUNTIME_DIR"
	--unshare-pid
	--unshare-ipc
	--unshare-uts
	--setenv XDG_RUNTIME_DIR "$RUNTIME_DIR"
	--setenv CLAUDE_CONFIG_DIR "$HOME/.claude"
	--setenv GIT_SSH_COMMAND "ssh -F /dev/null"
	--unsetenv RUSTC_WRAPPER # don't inherit a host wrapper; set one in the sandbox's ~/.cargo if wanted
	--setenv PATH "$HOME/.cargo/bin:$HOME/.local/bin:/usr/bin:/bin"
)

# --new-session guards against TIOCSTI injection into the host terminal, but it
# detaches the controlling tty and breaks interactive shells (fish). Kernels
# with legacy_tiocsti=0 already block TIOCSTI, so only add it where needed.
if [[ "$(cat /proc/sys/dev/tty/legacy_tiocsti 2>/dev/null || echo 1)" != "0" ]]; then
	BWRAP_ARGS+=(--new-session)
fi

# add "<kind> <path>" if path exists; kind is bind, ro-bind or dev-bind
function maybe() {
	if [[ -e "$2" ]]; then
		BWRAP_ARGS+=("--$1" "$2" "$2")
	fi
}

maybe ro-bind /boot
maybe ro-bind /usr
maybe ro-bind /etc
maybe ro-bind /opt
maybe ro-bind /sys
maybe ro-bind /var
BWRAP_ARGS+=(--symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64)

maybe ro-bind "/run/systemd/resolve"
maybe ro-bind "$HOME/.config/git/allowed_signers"
maybe ro-bind "$HOME/.risc0"
maybe bind "$HOME/.e16"

# Deliberate exception: agent config/auth/sessions are shared with the host
# (and thus between all sandboxes) so login and session resume keep working.
maybe bind "$HOME/.codex"
maybe bind "$HOME/.gemini"
maybe bind "$HOME/.claude"                  # also holds the ~/.claude.json symlink target
maybe bind "$HOME/Projects/dotfiles/claude" # target of ~/.claude/{settings.json,CLAUDE.md} symlinks
maybe bind "$HOME/.local/bin/claude"
maybe bind "$HOME/.local/share/claude"
maybe bind "$HOME/.local/state/claude"
maybe bind "$HOME/.omp"
maybe bind "$HOME/.config/omp"
maybe bind "$HOME/.config/opencode"
maybe bind "$HOME/.local/share/opencode"
maybe bind "$HOME/.local/state/opencode"

# opt-in binds: "<config var> <kind> <path>"
OPTIN=(
	"SBX_X11 bind $HOME/.Xauthority"
	"SBX_X11 bind /tmp/.X11-unix"
	"SBX_X11 bind /tmp/.XIM-unix"
	"SBX_X11 bind /tmp/.ICE-unix"
	"SBX_X11 bind /tmp/.font-unix"
	"SBX_GPU dev-bind /dev/dri"
	"SBX_KVM dev-bind /dev/kvm"
	"SBX_UDMABUF dev-bind /dev/udmabuf"
)
for entry in "${OPTIN[@]}"; do
	read -r var kind path <<<"$entry"
	if [[ "${!var}" == "1" ]]; then
		maybe "$kind" "$path"
	fi
done

# runtime-dir sockets are remapped from the host's XDG_RUNTIME_DIR
if [[ "$SBX_WAYLAND" == "1" && -n "${WAYLAND_DISPLAY:-}" ]]; then
	wl_sock="$WAYLAND_DISPLAY"
	[[ "$wl_sock" == /* ]] || wl_sock="$HOST_RUNTIME_DIR/$wl_sock"
	if [[ -e "$wl_sock" ]]; then
		BWRAP_ARGS+=(--bind "$wl_sock" "$RUNTIME_DIR/$(basename "$wl_sock")")
		BWRAP_ARGS+=(--setenv WAYLAND_DISPLAY "$(basename "$wl_sock")")
	fi
else
	BWRAP_ARGS+=(--unsetenv WAYLAND_DISPLAY)
fi
if [[ "$SBX_PIPEWIRE" == "1" ]]; then
	for s in pipewire-0 pipewire-0-manager; do
		if [[ -e "$HOST_RUNTIME_DIR/$s" ]]; then
			BWRAP_ARGS+=(--bind "$HOST_RUNTIME_DIR/$s" "$RUNTIME_DIR/$s")
		fi
	done
fi
if [[ "$SBX_SSH_AGENT" == "1" && -n "${SSH_AUTH_SOCK:-}" ]]; then
	maybe ro-bind "$HOME/.ssh/id_ed25519.pub"
	BWRAP_ARGS+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK" --setenv SSH_AUTH_SOCK "$SSH_AUTH_SOCK")
else
	BWRAP_ARGS+=(--unsetenv SSH_AUTH_SOCK)
fi
[[ "$SBX_NET" == "0" ]] && BWRAP_ARGS+=(--unshare-net)

for p in "${SBX_EXTRA_RO_BINDS[@]}"; do
	BWRAP_ARGS+=(--ro-bind "$p" "$p")
done

# now bind all argument paths
for p in "${PATHS[@]}"; do
	BWRAP_ARGS+=(--bind "$p" "$p")
done

BWRAP_ARGS+=(--chdir "${PATHS[0]}" --die-with-parent -- "${AGENT_CMD[@]}")

if [[ "$DEBUG" -eq 1 ]]; then
	echo "SANDBOX: $SBX"
	echo "ARGS: ${BWRAP_ARGS[*]}"
fi

exec bwrap "${BWRAP_ARGS[@]}"
