#!/bin/sh


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${CHISEL_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Default location of the chisel binary
if [ "$(id -u)" = "0" ]; then
  # Running as root, install to /usr/local/bin
  : "${CHISEL_BIN:=/usr/local/bin/chisel}"
else
  # Running as non-root, install to ~/.local/bin
  : "${CHISEL_BIN:=${XDG_BIN_HOME:-${HOME:-"/home/$(id -un)"}/.local/bin}/chisel}"
fi

# Version of chisel to install
: "${CHISEL_VERSION:=1.11.3}"

# URL to download chisel from
: "${CHISEL_INSTALL:=https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION#v}/chisel_${CHISEL_VERSION#v}_linux_amd64.gz}"

# URL to chisel server (for client mode)
: "${CHISEL_SERVER:=https://home.freconia.se/chisel/}"

# Location of the chisel server's auth file (for server mode)
: "${CHISEL_AUTH:=${CHISEL_SCRIPTDIR}/chisel.auth}"

# Verbosity level
: "${CHISEL_VERBOSE:=1}"

# PML: Poor Man's Logging on stderr
_log() {
  printf '[%s] [%s] [%s] ' \
    "$(basename "$0")" \
    "${1:-LOG}" \
    "$(date +'%Y%m%d-%H%M%S')" \
    >&2
  shift
  _fmt="$1"
  shift
  # shellcheck disable=SC2059 # ok, we want to use printf format
  printf "${_fmt}\n" "$@" >&2
}
trace() { [ "$CHISEL_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$CHISEL_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }

# Silently download a file using curl
# $1: URL
# $2: output file (optional, default: basename of URL)
download() { run_curl -o "${2:-$(basename "$1")}" "$1"; }

# Wrapper around curl to add common options
# $@: curl arguments
run_curl() {
  curl -fsSL --retry 5 --retry-delay 3 "$@"
}

info "Running as user: %s (uid=%s)" "$(id -un)" "$(id -u)"

if ! [ -x "$CHISEL_BIN" ]; then
  tmp="$(mktemp -u -t chisel-XXXXXX).gz"
  download "$CHISEL_INSTALL" "$tmp"
  gunzip -f "$tmp"
  chmod +x "${tmp%.gz}" && mv -f "${tmp%.gz}" "$CHISEL_BIN"
  info "Downloaded and installed chisel v%s to %s" "${CHISEL_VERSION#v}" "$CHISEL_BIN"
fi

# Set up options to client subcommand. Pick anything from the command line as
# options to the client. Enforce verbosity and content of auth file if present.
set -- -v "$@"
if [ -f "$CHISEL_AUTH" ]; then
    info "Using chisel auth file: %s" "$CHISEL_AUTH"
    AUTH=$(cat "$CHISEL_AUTH");  # Can also be exported instead, what best?
    set -- --auth "$AUTH" "$@"
  else
    warn "Chisel auth file not found: %s. Proceeding without auth." "$CHISEL_AUTH"
  fi

# Makes local port 22 available on the chisel server at port 15000.
exec ${CHISEL_BIN} client "$@" "$CHISEL_SERVER" R:15000:localhost:22
