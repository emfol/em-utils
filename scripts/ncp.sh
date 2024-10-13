#!/bin/sh

##
# Ensure proper shell options

set +o errexit
export GREP_OPTIONS=''

##
# Constants

NCP_SERVER_PORT="${NCP_SERVER_PORT:-1234}"

##
# Utilities

get_host_addresses() {
  (
    for ip_command in 'ifconfig' 'ip address list'; do
      ip_list=$("${SHELL}" -c "${ip_command}" 2>/dev/null)
      if [ $? -eq 0 ] && [ -n "${ip_list}" ]; then
        printf '%s\n' "${ip_list}" | \
          sed -En 's/.*inet[[:blank:]]+(addr:)?([0-9]+(\.[0-9]+){3}).*/\2/p' | \
          grep -E -v -e '127\.'
      fi
    done
  )
}

archive() {
  (
    cpio -o -v -H newc
  )
}

unarchive() {
  (
    cpio -i -dmuv
  )
}

walk_items() {
  (
    for item in "$@"; do
      if ([ ! -z "${item%%/*}" ] &&
          [ ! -z "${item%%./*}" ] &&
          [ ! -z "${item%%../*}" ]); then
        item="./${item}"
      fi
      if [ -d "${item}" ] && [ ! -L "${item}" ]; then
        find -H "${item}" \( -type f -o -type l \)
      elif [ -L "${item}" ] || [ -f "${item}" ]; then
        printf '%s\n' "${item}"
      else
        printf '[skip] %s\n' "${item}" >&2
      fi
    done
  )
}

archive_items() {
  (
    walk_items | archive
  )
}

start_server() {
  (
    get_host_addresses | (
      shift $#
      while read -r ipv4; do
        if [ -n "${ipv4}" ]; then
          set -- "$@" "${ipv4}"
        fi
      done
      if [ $# -gt 0 ]; then
        printf '@ Available IPv4 Addresses:\n' >&2
        printf '  - %s\n' "$@" >&2
      fi
    )
    echo nc -l 0.0.0.0 "${NCP_SERVER_PORT}"
  )
}

connect_to_server() {
  (
    ipv4="$1"
    echo nc "${ipv4}" "${NCP_SERVER_PORT}"
  )
}

if [ $# -gt 0 ]; then
  command=$1
  if [ "${command}" = "$(command -v "${command}" 2>/dev/null)" ]; then
    shift 1
    "${command}" "$@"
  fi
fi
