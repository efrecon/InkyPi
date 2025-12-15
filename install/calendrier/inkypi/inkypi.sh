#!/bin/bash


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${INKYPI_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Home directory for InkyPi
: "${INKYPI_ROOTDIR:=${INKYPI_SCRIPTDIR}/../../..}"

# venv path
: "${INKYPI_VENVDIR:=${INKYPI_ROOTDIR}/venv}"

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

if [ -f "${INKYPI_VENVDIR}/bin/activate" ]; then
  info "Activating venv: ${INKYPI_VENVDIR}"
  source "${INKYPI_VENVDIR}/bin/activate"
else
  error "Virtualenv not found: ${INKYPI_VENVDIR}"
fi

SRC_DIR="${INKYPI_ROOTDIR}/src"
if [ -f "${SRC_DIR}/inkypi.py" ]; then
  info "Starting InkyPi from: ${SRC_DIR}/inkypi.py"
else
  error "Source directory not found: ${SRC_DIR}"
fi

export SRC_DIR
exec python -u "$(realpath ${SRC_DIR}/inkypi.py)" --dev
