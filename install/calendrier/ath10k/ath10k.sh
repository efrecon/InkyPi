#!/bin/sh


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${ATH10K_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Name of the wifi interface to tune, empty for guess.
: "${ATH10K_INTERFACE:=""}"

# Name of the service to restart
: "${ATH10K_SERVICE:="NetworkManager"}"

# Verbosity level
: "${ATH10K_VERBOSE:=1}"

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
trace() { [ "$ATH10K_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$ATH10K_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }


[ -z "$ATH10K_INTERFACE" ] && ATH10K_INTERFACE=$(nmcli device status | grep -E 'wifi\s' | head -n 1 | awk '{print $1}' || true)
[ -z "$ATH10K_INTERFACE" ] && error "Could not determine wifi interface, please set ATH10K_INTERFACE variable"

info "Setting ath10k parameters"
echo "1" > /sys/module/ath10k_core/parameters/cryptmode
info "Cycling interface '%s' to apply changes" "$ATH10K_INTERFACE"
ip link set "$ATH10K_INTERFACE" down && ip link set "$ATH10K_INTERFACE" up
info "Restarting service '%s'" "$ATH10K_SERVICE"
systemctl restart "$ATH10K_SERVICE" || true
