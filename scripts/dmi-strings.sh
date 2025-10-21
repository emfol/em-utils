#!/bin/sh

sudo dmidecode --list-strings | (
  while read -r attr
  do
    printf ' - %s: "%s"\n' "${attr}" "$(sudo dmidecode -s "${attr}")"
  done
)
