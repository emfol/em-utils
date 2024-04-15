#!/bin/sh

set +o errexit
export GREP_OPTIONS=''

##
# Definittions

cmd="$0"
script="${cmd}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "${script}" 2>/dev/null)" >/dev/null 2>&1 && pwd -P)
script="${script_dir}/$(basename -- "${script}")"
local_bin_dir=$(CDPATH='' cd -- "${script_dir}/../bin" >/dev/null 2>&1 && pwd -P)
bcs_utility="${local_bin_dir}/bcs"
starts_with_utility="${local_bin_dir}/starts_with"
realpath_utility=$(command -v realpath 2>/dev/null)
dd_utility=$(command -v dd 2>/dev/null)
sha256sum_utility=$(command -v sha256sum 2>/dev/null)

##
# Helper Functions

print_abort() {
  (
    message="$1"
    printf ' > Aborting:\n   - %s\n' "${message}" >&2
  )
}

print_usage() {
  (
    printf '\n > Usage:\n\n\t%s [-y] -d <target_device> -f <image_file>\n\n' "${cmd}" >&2
  )
}

prompt_user() {
  (
    exec 3>&1 </dev/tty >/dev/tty 2>&1
    question="$1"
    printf '%s ' "${question}" >&2
    if ! read answer
    then
      printf '\n' >&2
    fi
    printf '%s\n' "${answer}" >&3
  )
}

device_is_available() {
  (
    target_device_path=$("${realpath_utility}" -q "$1" 2>/dev/null)
    if [ $? -ne 0 ] || [ ! -b "${target_device_path}" ]
    then
      print_abort 'Invalid block device.'
      exit 1
    fi
    mount 2>/dev/null | (
      while read -r device not_used
      do
        device_path=$("${realpath_utility}" -q "${device}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -b "${device_path}" ] && "${starts_with_utility}" "${target_device_path}" "${device_path}"
        then
          print_abort "Mounted file system for: ${device_path}"
          exit 1
        fi
      done
      exit 0
    )
  )
}

##
# Script Logic

# Make sure dependencies are available
for utility_name in bcs_utility starts_with_utility realpath_utility dd_utility sha256sum_utility
do
  utility=$(eval "printf '%s\n' \"\$${utility_name}\"")
  if [ -z "${utility}" ] || ! command -v "${utility}" >/dev/null 2>&1
  then
    print_abort "Dependency not found: ${utility_name%_utility}"
    exit 1
  fi
done

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
block_size=4096
file_size=0
chunk_size=0
chunk_count=0

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

# Try to determine best chunk size for copy
while [ "${chunk_size}" -lt 512 ] && [ "${block_size}" -ge 512 ]
do
  result=$("${bcs_utility}" -b "${block_size}" "${image_file}" 2>/dev/null)
  if [ $? -ne 0 ]
  then
    block_size=$((block_size / 2))
    continue
  fi
  chunk_size="${result%% *}"
  file_size="${result##* }"
  # Make sure the variables contain numeric values
  chunk_size=$((chunk_size + 0))
  file_size=$((file_size + 0))
done

# Print variables is DEBUG is enabled
if [ -n "${DEBUG}" ]
then
  printf ' > DEBUG:\n' >&2
  printf '   - %s: "%s"\n' \
    'bcs_utility' "${bcs_utility}" \
    'dd_utility' "${dd_utility}" \
    'sha256sum_utility' "${sha256sum_utility}" \
    'target_device' "${target_device}" \
    'image_file' "${image_file}" \
    'skip_confirm' "${skip_confirm}" \
    'block_size' "${block_size}" \
    'file_size' "${file_size}" \
    'chunk_size' "${chunk_size}" >&2
fi

# Abort if proper chunk size could not be determined.
if [ "${chunk_size}" -lt 512 ] || [ "${file_size}" -lt 512 ] || [ "${block_size}" -lt 512 ]
then
  printf ' > Aborting: the proper chunk size for data transfer could not be determined...\n' >&2
  exit 1
fi

# Make sure the number and size of chunks match the total file size.
chunk_count=$((file_size / chunk_size))
if [ "$((chunk_count * chunk_size))" -ne "${file_size}" ]
then
  printf ' > Aborting: unexpected mismatch for number and size of data transfer chunks...\n' >&2
  exit 1
fi

# Print variables is DEBUG is enabled
if [ -n "${DEBUG}" ]
then
  printf ' > DEBUG:\n' >&2
  printf '   - A total of %s data chunks will be written to "%s"\n' \
    "${chunk_count}" "${target_device}" >&2
fi

# Check if target device is available
if ! device_is_available "${target_device}"
then
  exit 1
fi

# Confirm data loss in target device
if [ -z "${skip_confirm}" ]
then
  question=" > DATA IN \"${target_device}\" WILL BE LOST!!! CONTINUE? [y|N]"
  answer=$(prompt_user "${question}" | tr '[:upper:]' '[:lower:]' )
  if [ "X${answer}" != 'Xy' ] && [ "X${answer}" != 'Xyes' ]
  then
    printf ' > Aborting...\n' >&2
    exit 1
  fi
fi

# Prepare arguments for dd utility
set -- \
  "if=${image_file}" \
  "of=${target_device}" \
  "bs=${chunk_size}" \
  oflag=sync \
  status=progress

# TODO:
echo "${dd_utility}" "$@"
