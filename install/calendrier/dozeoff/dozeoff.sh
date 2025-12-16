#!/bin/sh


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${DOZEOFF_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Name of the service to stop
: "${DOZEOFF_SERVICE:=fbi}"

# TTY where to force the blanking
_tty=$(tty || true)
if [ "$_tty" = "not a tty" ] || [ -z "$_tty" ]; then
  _tty="/dev/tty1"
fi
: "${DOZEOFF_TTY:="$_tty"}"

# Verbosity level
: "${DOZEOFF_VERBOSE:=1}"

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
trace() { [ "$DOZEOFF_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$DOZEOFF_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }

if [ -n "$DOZEOFF_SERVICE" ]; then
  info "Stopping service %s" "$DOZEOFF_SERVICE"
  systemctl stop "$DOZEOFF_SERVICE" || true
else
  warn "No service specified to stop"
fi

setterm --term linux --blank force < "$DOZEOFF_TTY" || error "Failed to force blanking on %s" "$DOZEOFF_TTY"

