#!/bin/sh


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${WAKEUP_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Name of the service to start
: "${WAKEUP_SERVICE:=fbi}"

# Verbosity level
: "${WAKEUP_VERBOSE:=1}"

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
trace() { [ "$WAKEUP_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$WAKEUP_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }


if [ -n "$WAKEUP_SERVICE" ]; then
  info "Starting service %s" "$WAKEUP_SERVICE"
  systemctl enable "$WAKEUP_SERVICE" || true
  systemctl start "$WAKEUP_SERVICE" || true
else
  warn "No service specified to start"
fi

