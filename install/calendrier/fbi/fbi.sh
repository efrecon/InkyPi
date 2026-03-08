#!/bin/bash


set -eu
# shellcheck disable=SC3040 # now part of POSIX, but not everywhere yet!
if set -o | grep -q 'pipefail'; then set -o pipefail; fi

# Root directory where this script is located
: "${FBI_SCRIPTDIR:="$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )"}"

# Home directory for InkyPi
: "${FBI_INKYDIR:=${FBI_SCRIPTDIR}/../../..}"

# Location of the images.
: "${FBI_IMAGESDIR:=${FBI_INKYDIR}/src/static/images}"

# Device to use for displaying images
: "${FBI_DEVICE:=""}"

# Timeout between images
: "${FBI_TIMEOUT:=5}"

# Virtual console to use
: "${FBI_CONSOLE:="4"}"

# Verbosity level
: "${FBI_VERBOSE:=1}"

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
trace() { [ "$FBI_VERBOSE" -ge "2" ] && _log DBG "$@" || true ; }
info() { [ "$FBI_VERBOSE" -ge "1" ] && _log NFO "$@" || true ; }
warn() { _log WRN "$@"; }
error() { _log ERR "$@" && exit 1; }

[ -f "${FBI_IMAGESDIR%%/}/current_image.png" ] || error "No current_image.png found in ${FBI_IMAGESDIR}"
for ghost in current_image_ghost_1.png current_image_ghost_2.png; do
  if [ -f "${FBI_IMAGESDIR%%/}/${ghost}" ]; then
    trace "ghost image: ${FBI_IMAGESDIR%%/}/${ghost} already present"
  else
    info "Creating ghost image link: ${FBI_IMAGESDIR%%/}/${ghost} -> current_image.png"
    ( cd "${FBI_IMAGESDIR%%/}" && ln -s current_image.png "${ghost}" )
  fi
done

if [ -z "$FBI_DEVICE" ]; then
  info "Detecting FBI device"
  FBI_DEVICE=$(find /dev/dri -maxdepth 1 -name 'card*' | sort | tail -n 1)
fi
[ -z "$FBI_DEVICE" ] && error "No FBI device found under /dev/dri/card*"

info "Displaying images from InkyPi on device: $FBI_DEVICE"
exec fbi \
        -autozoom \
        -device "$FBI_DEVICE" \
        -nocomments \
        -noverbose \
        -nointeractive \
        -timeout "${FBI_TIMEOUT}" \
        -cachemem 0 \
        -vt "${FBI_CONSOLE}" \
          "${FBI_IMAGESDIR%%/}/current_image.png" \
          "${FBI_IMAGESDIR%%/}/current_image_ghost_1.png" \
          "${FBI_IMAGESDIR%%/}/current_image_ghost_2.png"
