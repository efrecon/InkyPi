#!/bin/sh


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${REBOOT_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Name of the service to stop
: "${REBOOT_SERVICE:=fbi}"

# Verbosity level
: "${REBOOT_VERBOSE:=1}"

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
trace() { [ "$REBOOT_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$REBOOT_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }


if [ -n "$REBOOT_SERVICE" ]; then
  info "Stopping service %s" "$REBOOT_SERVICE"
  systemctl stop "$REBOOT_SERVICE" || true
  systemctl disable "$REBOOT_SERVICE" || true
else
  warn "No service specified to stop"
fi

info "Rebooting system now..."
/sbin/reboot
