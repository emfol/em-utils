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
bcs_cmd="${local_bin_dir}/bcs"
starts_with_cmd="${local_bin_dir}/starts_with"
realpath_cmd=$(command -v realpath 2>/dev/null)
dd_cmd=$(command -v dd 2>/dev/null)
sha256sum_cmd=$(command -v sha256sum 2>/dev/null)
gdisk_cmd=$(command -v gdisk 2>/dev/null)
blockdev_cmd=$(command -v blockdev 2>/dev/null)
min_block_size=512

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

is_supported_block_device() {
  (
    target_device_path="$1"
    if [ -b "${target_device_path}" ]
    then
      sector_size=$("${blockdev_cmd}" --getss "${target_device_path}" 2>/dev/null)
      if [ -n "${DEBUG}" ]
      then
        printf ' > DEBUG:\n' >&2
        printf '   - %s: "%s"\n' \
          'min_block_size' "${min_block_size}" \
          'sector_size' "${sector_size}"
      fi
      if [ "X${sector_size}" = "X${min_block_size}" ]
      then
        exit 0
      fi
    fi
    exit 1
  )
}

device_is_available() {
  (
    try_umount=''
    if [ "X$1" = 'X--umount' ]
    then
      try_umount='yes'
      shift 1
    fi
    target_device_path=$("${realpath_cmd}" -q "$1" 2>/dev/null)
    if [ $? -ne 0 ] || [ ! -b "${target_device_path}" ]
    then
      print_abort 'Invalid block device.'
      exit 2
    fi
    mount 2>/dev/null | (
      has_mounted_partitions=''
      while read -r device not_used
      do
        device_path=$("${realpath_cmd}" -q "${device}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -b "${device_path}" ] && "${starts_with_cmd}" "${target_device_path}" "${device_path}"
        then
          if [ -n "${try_umount}" ]
          then
            umount "${device_path}" >/dev/null 2>&1
            has_mounted_partitions='yes'
          else
            print_abort "Mounted file system for: ${device_path}"
            exit 2
          fi
        fi
      done
      test -z "${has_mounted_partitions}"
    )
  )
}

wipe_gpt() {
  (
    target_device_path="$1"
    printf '%s\n' x z Y Y | gdisk "${target_device_path}" >/dev/null 2>&1
  )
}

##
# Script Logic

# Make sure dependencies are available
for utility_name in bcs_cmd starts_with_cmd realpath_cmd dd_cmd sha256sum_cmd gdisk_cmd blockdev_cmd
do
  utility=$(eval "printf '%s\n' \"\$${utility_name}\"")
  if [ -z "${utility}" ] || ! command -v "${utility}" >/dev/null 2>&1
  then
    print_abort "Dependency not found: ${utility_name%_cmd}"
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

# Make sure the target device is valid and supported
if ! is_supported_block_device "${target_device}"
then
  print_abort "Invalid or unsupported device: ${target_device}"
  exit 1
fi

# Try to determine best chunk size for copy
while [ "${chunk_size}" -lt "${min_block_size}" ] && [ "${block_size}" -ge "${min_block_size}" ]
do
  result=$("${bcs_cmd}" -b "${block_size}" "${image_file}" 2>/dev/null)
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
    'bcs_cmd' "${bcs_cmd}" \
    'starts_with_cmd' "${starts_with_cmd}" \
    'realpath_cmd' "${realpath_cmd}" \
    'dd_cmd' "${dd_cmd}" \
    'sha256sum_cmd' "${sha256sum_cmd}" \
    'gdisk_cmd' "${gdisk_cmd}" \
    'blockdev_cmd' "${blockdev_cmd}" \
    'target_device' "${target_device}" \
    'image_file' "${image_file}" \
    'skip_confirm' "${skip_confirm}" \
    'block_size' "${block_size}" \
    'file_size' "${file_size}" \
    'chunk_size' "${chunk_size}" >&2
fi

# Abort if proper chunk size could not be determined.
if [ "${chunk_size}" -lt "${min_block_size}" ] || [ "${file_size}" -lt "${min_block_size}" ] || [ "${block_size}" -lt "${min_block_size}" ]
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
device_is_available --umount "${target_device}"
status="$?"
if [ "${status}" -gt 0 ]
then
  if [ "${status}" -gt 1 ]
  then
    exit 1
  fi
  if ! device_is_available "${target_device}"
  then
    exit 1
  fi
fi

# Confirm data loss in target device
if [ -z "${skip_confirm}" ]
then
  question=" > DATA IN \"${target_device}\" WILL BE LOST!!! CONTINUE? [y|N]"
  answer=$(prompt_user "${question}" | tr '[:upper:]' '[:lower:]')
  if [ "X${answer}" != 'Xy' ] && [ "X${answer}" != 'Xyes' ]
  then
    printf ' > Aborting...\n' >&2
    exit 1
  fi
fi

# Wipe device
if ! wipe_gpt "${target_device}"
then
  print_abort "Error wiping target device: ${target_device}"
fi

# Prepare arguments for dd utility
set -- \
  "if=${image_file}" \
  "of=${target_device}" \
  "bs=${chunk_size}" \
  oflag=sync \
  status=progress

# TODO:
echo "${dd_cmd}" "$@"
