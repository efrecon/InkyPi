#!/bin/bash


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${INKYPI_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Home directory for InkyPi
: "${INKYPI_ROOTDIR:=${INKYPI_SCRIPTDIR}/../../..}"

# Directory for config files
: "${INKYPI_CFGDIR:=${INKYPI_ROOTDIR}/src/config}"

# Main and host dependent configurations
: "${INKYPI_MAIN_CFG:=${INKYPI_CFGDIR}/device_dev.json}"
: "${INKYPI_HOST_CFG:=${INKYPI_CFGDIR}/device_dev.$(hostname).json}"

# venv path
: "${INKYPI_VENVDIR:=${INKYPI_ROOTDIR}/venv}"

# Stop PID. When non-empty, will be used to stop the running InkyPi process
: "${INKYPI_PID:=}"

# Number of seconds to wait for PID to be gone before forcefully killing it
: "${INKYPI_TIMEOUT:=90}"

# Verbosity level
: "${INKYPI_VERBOSE:=1}"

usage() {
  # This uses the comments behind the options to show the help. Not extremely
  # correct, but effective and simple.
  echo "$0 starts/stops InkyPi" && \
    grep "[[:space:]].)[[:space:]][[:space:]]*#" "$0" |
    sed 's/#//' |
    sed -E 's/([a-zA-Z-])\)/-\1/'
  printf \\nEnvironment:\\n
  set | grep '^INKYPI_' | sed 's/^INKYPI_/    INKYPI_/g'
  exit "${1:-0}"
}

# Parse named arguments using getopts
while getopts ":p:vh-" opt; do
  case "$opt" in
    p) # Stop PID. When non-empty, will be used to stop the running InkyPi process
      INKYPI_PID=$OPTARG;;
    v) # Increase verbosity each time repeated
      INKYPI_VERBOSE=$(( INKYPI_VERBOSE + 1 ));;
    h) # Show this help
      usage 0;;
    -) # Takes name of destination file as argument, empty or "-" means stdout
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND -1))

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

# Pick owner of the configuration directory, will own the copied files.
INKYPI_OWNER=$(stat -c '%U:%G' "$INKYPI_CFGDIR")

if [ -z "$INKYPI_PID" ]; then
  # Make sure we know where it is and there is an inkypi there.
  SRC_DIR="${INKYPI_ROOTDIR}/src"
  if [ -f "${SRC_DIR}/inkypi.py" ]; then
    info "Starting InkyPi from: ${SRC_DIR}/inkypi.py"
  else
    error "Source directory not found: ${SRC_DIR}"
  fi

  # Copy host configuration to main configuration if it exists
  if [ -f "${INKYPI_HOST_CFG}" ]; then
    info "Using host configuration: ${INKYPI_HOST_CFG}"
    cp -f "${INKYPI_HOST_CFG}" "${INKYPI_MAIN_CFG}"
    chown "${INKYPI_OWNER}" "${INKYPI_MAIN_CFG}"
  fi

  # Start InkyPi
  export SRC_DIR
  exec python -u "$(realpath ${SRC_DIR}/inkypi.py)" --dev
else
  # Stop InkyPi process if PID is provided
  kill "$INKYPI_PID"

  # Wait until it has stopped, force kill it if it takes too long.
  _wait=1; _waited=0
  while kill -0 "$INKYPI_PID" 2>/dev/null; do
    info "Waiting for InkyPi process $INKYPI_PID to exit..."
    sleep "$_wait"
    _waited=$(( _waited + _wait ))
    _wait=$(( _wait * 2 )) # Exponential backoff for waiting time 
    [ "$_wait" -ge 5 ] && _wait=5
    if [ "$_waited" -ge "$INKYPI_TIMEOUT" ]; then
      info "Force killing $INKYPI_PID"
      kill -9 "$INKYPI_PID"
      break
    fi

  done

  # Copy main configuration to host configuration
  info "Saving main configuration to host configuration"
  cp -f "${INKYPI_MAIN_CFG}" "${INKYPI_HOST_CFG}"
  chown "${INKYPI_OWNER}" "${INKYPI_HOST_CFG}"
fi
