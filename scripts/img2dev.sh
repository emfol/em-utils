#!/bin/sh

set +o errexit
export GREP_OPTIONS=''

# Ensure root privileges
if [ "X$(id -u)" != 'X0' ]
then
  if [ $# -lt 1 ] || [ "X$1" != 'X--noesc' ]
  then
    script="$0"
    script_dir=$(CDPATH='' cd -- "$(dirname -- "${script}")" >/dev/null && pwd -P)
    script="${script_dir}/$(basename -- "${script}")"
    sudo "${script}" --noesc "$@"
    exit $?
  fi
  printf ' > Root privileges required...\n' >&2
  exit 1
elif [ $# -gt 0 ] && [ "X$1" = 'X--noesc' ]
then
  shift 1
fi

image_file="$1"
target_device="$2"


