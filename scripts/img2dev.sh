#!/bin/sh

set +o errexit
export GREP_OPTIONS=''

print_usage() {
  (
    script="$0"
    printf '\n > Usage:\n\n\t%s [-y] -d <target_device> -f <image_file>\n\n' "${script}" >&2
  )
}


prompt_user() {
  (
    exec 3>&1 </dev/tty >/dev/tty 2>&1
    printf '%s ' "$1" >&2
    read answer
    printf '%s\n' "${answer}" >&3
  )
}

# Make sure referred arguments are provided.
if [ $# -lt 1 ]
then
  print_usage
  exit 1
fi

# Ensure root privileges.
if [ "X$(id -u)" != 'X0' ]
then
  if [ "X$1" != 'X--noesc' ]
  then
    script="$0"
    script_dir=$(CDPATH='' cd -- "$(dirname -- "${script}")" >/dev/null && pwd -P)
    script="${script_dir}/$(basename -- "${script}")"
    sudo -E "${script}" --noesc "$@"
    exit $?
  fi
  printf ' > Root privileges required...\n' >&2
  exit 1
fi

# Remove the special "--noesc" (no-escalation) argument.
if [ "X$1" = 'X--noesc' ]
then
  shift 1
fi

# Initialize main application variables
skip_confirm=''
image_file=''
target_device=''

# Parse options
while getopts ':yd:f:' arg
do
  case "${arg}" in
  y)
    skip_confirm='yes'
    ;;
  d)
    target_device="${OPTARG}"
    ;;
  f)
    image_file="${OPTARG}"
    ;;
  :|?)
    print_usage
    exit 1
    ;;
  esac
done

shift $((OPTIND - 1))

# Make sure required arguments are provided
if [ $# -gt 0 ] || [ -z "${image_file}" ] || [ -z "${target_device}" ]
then
  print_usage
  exit 1
fi

# Print variables is DEBUG is enabled
if [ -n "${DEBUG}" ]
then
  printf ' > DEBUG:\n' >&2
  printf '   - %s: "%s"\n' \
    'target_device' "${target_device}" \
    'image_file' "${image_file}" \
    'skip_confirm' "${skip_confirm}" >&2
fi

# Confirm data loss
if [ -z "${skip_confirm}" ]
then
  question=" > DATA IN \"${target_device}\" WILL BE ERASED!!! CONTINUE? [y|N]"
  answer=$(prompt_user "${question}" | tr '[:upper:]' '[:lower:]' )
  if [ "X${answer}" != 'Xy' ] && [ "X${answer}" != 'Xyes' ]
  then
    printf ' > Aborted...\n' >&2
    exit 0
  fi
fi

# TODO:
echo dd if="${image_file}" of="${target_device}"
