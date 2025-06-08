#!/bin/sh

set -e

cmd="$1"
shift 1

printf ' > Executing command "%s" with args:\n' "${cmd}"
printf '   - "%s"\n' "$@"

if result=$("${cmd}" "$@")
then
  printf ' > Result is: %s\n\n' "${result}"
else
  printf ' > Bad command...\n\n'
fi
