#!/bin/sh

set +e
export GREP_OPTIONS=''

##
# Definitions

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
    exec 3>&1 </dev/tty >/dev/tty
    while [ $# -gt 0 ]
    do
      prompt="$1"
      shift
      if [ $# -eq 0 ]
      then
        printf '%s' "${prompt}"
      else
        printf '%s\n' "${prompt}"
      fi
    done
    if ! read -r answer
    then
      printf '\n'
      exit 1
    fi
    printf '%s\n' "${answer}" >&3
    exit 0
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
          'sector_size' "${sector_size}" >&2
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
      print_abort 'Invalid block device...'
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
            printf ' > INFO:\n' >&2
            printf '   - Trying to unmount: "%s"...\n' "${device_path}" >&2
            umount "${device_path}" >/dev/null 2>&1
            has_mounted_partitions='yes'
          else
            print_abort "Mounted file system for: \"${device_path}\"..."
            exit 2
          fi
        fi
      done
      test -z "${has_mounted_partitions}"
    )
  )
}

has_gpt_and_mbr() {
  (
    target_device_path="$1"
    printf '%s\n' 2 | (
      (
        "${gdisk_cmd}" -l "${target_device_path}" | grep -Fic -e 'Found valid MBR and GPT.' -e 'Using GPT' | (
          read -r count && test 2 -eq "${count}"
        )
      ) && ! read -r input
    )
  )
}

wipe_gpt() {
  (
    target_device_path="$1"
    (
      if has_gpt_and_mbr "${target_device_path}" >/dev/null 2>&1
      then
        set -- 2 x z Y Y
      else
        set -- x z Y Y
      fi
      printf '%s\n' "$@"
    ) | "${gdisk_cmd}" "${target_device_path}" >/dev/null 2>&1
  )
}

get_sha256sum() {
  (
    filepath="$1"
    if result=$("${sha256sum_cmd}" "${filepath}" 2>/dev/null)
    then
      printf '%s\n' "${result%% *}"
      exit 0
    fi
    exit 1
  )
}

get_file_segments() {
  (
    path="$1"
    wc -c -- "${path}" | (
      if ! read size name
      then exit 1
      fi
      for block in $((4 * 1024 * 1024)) $((1024 * 1024)) $((4 * 1024)) 512 1
      do
        if ! [ "${size}" -gt 0 ]
        then break
        fi
        if ! remainder=$(($size % $block))
        then exit 2
        fi
        if ! segment=$(($size - $remainder))
        then exit 3
        fi
        if ! count=$(($segment / $block))
        then exit 4
        fi
        size="${remainder}"
        if [ "${count}" -gt 0 ]
        then printf '%d %d\n' "${block}" "${count}"
        fi
      done
      exit 0
    )
  )
}

get_file_segments "$@"
exit $?

##
# Script Logic

# Make sure dependencies are available
for utility_name in bcs_cmd starts_with_cmd realpath_cmd dd_cmd sha256sum_cmd gdisk_cmd blockdev_cmd
do
  utility=$(eval "printf '%s\n' \"\$${utility_name}\"")
  if [ -z "${utility}" ] || ! command -v "${utility}" >/dev/null 2>&1
  then
    print_abort "Dependency not found: \"${utility_name%_cmd}\"..."
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
  print_abort "Invalid or unsupported device: \"${target_device}\"..."
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
  print_abort 'The proper chunk size for data transfer could not be determined...'
  exit 1
fi

# Make sure the number and size of chunks match the total file size.
chunk_count=$((file_size / chunk_size))
if [ "$((chunk_count * chunk_size))" -ne "${file_size}" ]
then
  print_abort 'Unexpected mismatch for number and size of data transfer chunks...'
  exit 1
fi


printf ' > INFO:\n' >&2
printf '   - The source image "%s" will be written to "%s";\n' \
  "${image_file}" "${target_device}" >&2
printf '   - The total payload of %s bytes will be split into chunks of %s bytes;\n' \
  "${file_size}" "${chunk_size}" >&2
printf '   - A total of %s data chunks will be written to "%s";\n' \
  "${chunk_count}" "${target_device}" >&2


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
  answer=$(prompt_user "${question} " | tr '[:upper:]' '[:lower:]') :
  if [ "/${answer}" != '/y' ] && [ "/${answer}" != '/yes' ]
  then
    printf ' > Aborting...\n' >&2
    exit 1
  fi
fi

printf ' > INFO:\n' >&2
printf '   - Wiping target device: "%s";\n' "${target_device}" >&2

# Wipe device
if ! wipe_gpt "${target_device}"
then
  print_abort "Error wiping target device: \"${target_device}\"..."
  exit 1
fi

printf ' > INFO:\n' >&2
printf '   - Calculating the SHA-256 checksum of the source image file: "%s";\n' "${image_file}" >&2

checksum=$(get_sha256sum "${image_file}")
if [ $? -eq 0 ] && [ ${#checksum} -eq 64 ]
then
  printf '   - SHA-256 Checksum: "%s";\n' "${checksum}" >&2
else
  print_abort 'SHA-256 Checksum could not be calculated...'
  exit 1
fi

# Prepare arguments for writting.
set -- \
  "if=${image_file}" \
  "of=${target_device}" \
  "bs=${chunk_size}" \
  "count=${chunk_count}" \
  iflag=fullblock \
  oflag=sync \
  status=progress

printf ' > INFO:\n' >&2
printf '   - Writing source image to target device with params:\n' >&2
printf '      - %s\n' "$@" >&2
printf '\n' >&2

"${dd_cmd}" "$@" </dev/tty >/dev/tty 2>&1
if [ $? -ne 0 ]
then
  print_abort 'Error writing source image to target device...'
  exit 1
fi

printf '\n' >&2
printf ' > INFO:\n' >&2
printf '   - Verifying...\n' >&2
printf '\n' >&2

# Make sure the data has been written to disk.
sync

# Prepare arguments for verification.
set -- \
  "if=${target_device}" \
  "bs=${chunk_size}" \
  "count=${chunk_count}" \
  iflag=fullblock \
  status=progress

result=$("${dd_cmd}" "$@" </dev/tty 2>/dev/tty | get_sha256sum -)
if [ $? -ne 0 ] || [ "X${result}" != "X${checksum}" ]
then
  print_abort "Verification failed: \"${result}\" does not match \"${checksum}\"..."
  exit 1
fi

printf '\n' >&2
printf ' > INFO:\n' >&2
printf '   - Done!\n\n' >&2
exit 0
