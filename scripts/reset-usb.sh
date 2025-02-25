#!/bin/sh

(
  for i in /sys/bus/pci/drivers/[uoex]hci_hcd/*:*; do
    bus_id="${i##*/}"
    dir="${i%/*}"
    if [ ! -e "${i}" ]; then
      continue
    fi
    printf ' > "%s" -> "%s"\n' "${bus_id}" "${dir}"
    printf '%s\n' "${bus_id}" | sudo tee "${dir}/unbind"
    printf '%s\n' "${bus_id}" | sudo tee "${dir}/bind"
  done
)
