#!/bin/sh

sudo dmidecode -s 2>&1 | (
  grep -E -e '^[[:blank:]]+[^[:blank:]]+' | (
    while read -r attr
    do
      printf ' - %s: "%s"\n' "${attr}" "$(sudo dmidecode -s "${attr}")"
    done
  )
)
