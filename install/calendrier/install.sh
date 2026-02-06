#!/bin/bash


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${INKYPI_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Home directory for InkyPi
: "${INKYPI_ROOTDIR:=${INKYPI_SCRIPTDIR}/../..}"

# Verbosity level
: "${INKYPI_VERBOSE:=1}"

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
trace() { [ "$INKYPI_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$INKYPI_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }

[ "$(id -u)" = "0" ] || error "This script must be run as root"
INKYPI_INSTDIR=${INKYPI_ROOTDIR}/install/calendrier

install_unit() {
  if [ -z "${2:-}" ]; then
    if [ -f "${INKYPI_INSTDIR}/${1}/${1}.timer" ]; then
      _type="timer"
    else
      _type="service"
    fi
  else
    _type="$2"
  fi

  info "Removing existing %s %s if any" "$1" "$_type"
  systemctl stop "${1}.${_type}" || true
  systemctl disable "${1}.${_type}" || true

  info "Installing %s %s files" "$1" "$_type"
  for ext in service timer auth; do
    [ -f "${INKYPI_INSTDIR}/${1}/${1}.${ext}" ] && cp -f "${INKYPI_INSTDIR}/${1}/${1}.${ext}" "/etc/systemd/system/${1}.${ext}"
  done
  if [ -f "${INKYPI_INSTDIR}/${1}/${1}.sh" ]; then
    cp -f "${INKYPI_INSTDIR}/${1}/${1}.sh" "/usr/local/bin/${1}.sh"
    chmod +x "/usr/local/bin/${1}.sh"
  fi

  info "Enabling and starting %s %s" "$1" "$_type"
  systemctl daemon-reload
  systemctl enable "${1}.${_type}"
  systemctl start "${1}.${_type}"
}

if [ "$#" = 0 ]; then
  find "${INKYPI_INSTDIR}" -maxdepth 1 -mindepth 1 -type d -exec basename \{\} \; | while read -r unit; do
    install_unit "$unit"
  done
else
  for unit in "$@"; do
    install_unit "$unit"
  done
fi
