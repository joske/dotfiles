#!/usr/bin/env bash
#
# macOS counterpart to bwrap.sh, backed by Seatbelt (sandbox-exec).
#
# Threat model: accidental damage by the agent, NOT a hostile escape. Seatbelt
# has no mount namespaces, so $HOME cannot be hidden and re-composed the way
# bwrap.sh does it. Instead reads are left wide open and only writes are
# confined: everything under $HOME (plus the user-owned Homebrew and
# /usr/local prefixes) is read-only except the paths passed on the command
# line and the few state dirs the agent needs to function.
#
# Consequence worth knowing: this stops the agent clobbering your home dir or
# an unrelated project. It does NOT stop a destructive git command inside a
# directory you deliberately handed over, and it is not a security boundary.

set -euo pipefail

usage() {
	echo "Usage: $0 [-d] [-p] [-S] [-s session-name] <path> [path...]"
	echo "  First path must be a directory (used as working directory)."
	echo "  The listed paths are the ONLY writable locations outside cache/state dirs."
	echo "  -s name: resume the named session"
	echo "  -d: run bash instead of claude for debugging"
	echo "  -p: print the generated Seatbelt profile and exit"
	echo "  -S: take an APFS local snapshot before starting (instant rollback point)"
	exit 1
}

NAME=""
DEBUG=0
PRINT=0
SNAPSHOT=0
while true; do
	case "${1:-}" in
	-d) DEBUG=1; shift ;;
	-p) PRINT=1; shift ;;
	-S) SNAPSHOT=1; shift ;;
	-s) [[ $# -ge 2 ]] || usage; NAME="$2"; shift 2 ;;
	-a) echo "Error: only claude is supported by this script"; exit 1 ;;
	-*) usage ;;
	*) break ;;
	esac
done

[[ $# -ge 1 ]] || usage

PATHS=()
for arg in "$@"; do
	if ! p=$(realpath "$arg" 2>/dev/null) || [[ ! -e "$p" ]]; then
		echo "Error: '$arg' does not exist"
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

HOME_R=$(realpath "$HOME")

# Seatbelt evaluates rules in order, last match wins, and subpath rules apply
# to paths that do not exist yet. Paths must be fully resolved: /tmp, /etc and
# /var are symlinks into /private and the profile matches post-resolution.
RULES=()

esc() { printf '%s' "$1" | sed 's/["\\]/\\&/g'; }

deny_write() { RULES+=("(deny file-write* (subpath \"$(esc "$1")\"))"); }

# No existence check: subpath rules cover dirs the agent creates later.
allow_write_subpath() { RULES+=("(allow file-write* (subpath \"$(esc "$1")\"))"); }

allow_write_path() {
	if [[ -d "$1" ]]; then
		RULES+=("(allow file-write* (subpath \"$(esc "$1")\"))")
	else
		RULES+=("(allow file-write* (literal \"$(esc "$1")\"))")
	fi
}

# 1. Everything the user owns and could plausibly destroy.
deny_write "$HOME_R"
deny_write /opt/homebrew
deny_write /usr/local
deny_write /Users/Shared

# 2. Re-open the workspace(s) named on the command line.
for p in "${PATHS[@]}"; do
	allow_write_path "$p"
done

# 3. Re-open agent state and build caches, or nothing works.
allow_write_subpath "$HOME_R/.claude"
allow_write_path "$HOME_R/.claude.json"
allow_write_subpath "$HOME_R/.local/share/claude"
allow_write_subpath "$HOME_R/.local/state/claude"
allow_write_subpath "$HOME_R/.cache"
allow_write_subpath "$HOME_R/.cargo"
allow_write_subpath "$HOME_R/.rustup"
allow_write_subpath "$HOME_R/.npm"
allow_write_subpath "$HOME_R/Library/Caches"

# 4. Hard denies, last so they beat every allow above. A workspace inside one
#    of these stays read-only by design; check with -p if writes are refused.
deny_write "$HOME_R/.ssh"
deny_write "$HOME_R/.gnupg"
deny_write "$HOME_R/.aws"
deny_write "$HOME_R/.config/gh"
deny_write "$HOME_R/Library/Keychains"
deny_write "$HOME_R/Library/Mobile Documents"
deny_write "$HOME_R/Library/CloudStorage"

PROFILE="(version 1)
(allow default)
$(printf '%s\n' "${RULES[@]}")"

if [[ "$PRINT" -eq 1 ]]; then
	printf '%s\n' "$PROFILE"
	exit 0
fi

if [[ "$DEBUG" -eq 1 ]]; then
	AGENT_CMD=(bash)
else
	AGENT_CMD=(claude --dangerously-skip-permissions)
	for p in "${PATHS[@]:1}"; do
		AGENT_CMD+=(--add-dir "$p")
	done
	if [[ -n "$NAME" ]]; then
		AGENT_CMD+=(--resume "$NAME")
	fi
fi

if [[ "$SNAPSHOT" -eq 1 ]]; then
	tmutil localsnapshot || echo "Warning: snapshot failed, continuing"
fi

cd "${PATHS[0]}"

exec /usr/bin/sandbox-exec -p "$PROFILE" \
	/usr/bin/env RUSTC_WRAPPER="" "${AGENT_CMD[@]}"
