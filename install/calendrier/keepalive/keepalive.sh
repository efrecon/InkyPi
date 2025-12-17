#!/bin/sh


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${KEEPALIVE_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Name of the service to restart
: "${KEEPALIVE_SERVICE:="NetworkManager"}"

# Name of the host to resolve
: "${KEEPALIVE_HOST:="google.com"}"

# Where to store restart counts
: "${KEEPALIVE_STATEFILE:="/run/keepalive.state"}"

# How many restarts before reboots
: "${KEEPALIVE_REBOOT:=6}"

# Verbosity level
: "${KEEPALIVE_VERBOSE:=1}"

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
trace() { [ "$KEEPALIVE_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$KEEPALIVE_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }

name=$(getent hosts "$KEEPALIVE_HOST" || true)
if [ -n "$name" ]; then
  ip=$(echo "$name" | awk '{print $1}' | head -n1)
  info "Host %s is at %s, no action needed" "$KEEPALIVE_HOST" "$ip"
  exit 0
else
  if [ -f "$KEEPALIVE_STATEFILE" ]; then
    count=$(cat "$KEEPALIVE_STATEFILE" || echo "0")
    count=$((count + 1))
  else
    count=1
  fi
  echo "$count" > "$KEEPALIVE_STATEFILE" || warn "Failed to write state file %s" "$KEEPALIVE_STATEFILE"

  if [ "$count" -ge "$KEEPALIVE_REBOOT" ]; then
    warn "Host %s has been unreachable %d times, rebooting system" "$KEEPALIVE_HOST" "$count"
    rm -f "$KEEPALIVE_STATEFILE" || warn "Failed to remove state file %s" "$KEEPALIVE_STATEFILE"
    systemctl start reboot || true
    exit 0
  else
    warn "Host %s is not reachable, restarting %s" "$KEEPALIVE_HOST" "$KEEPALIVE_SERVICE"
    systemctl restart "$KEEPALIVE_SERVICE" || true
  fi
fi
