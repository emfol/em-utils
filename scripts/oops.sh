#!/bin/sh

set -e

a=$1
b=$2

if ! [ "${a}" -eq 0 ]
then
  printf 'First value is NOT zero...\n'
fi

if r=$(expr "${a}" '*' "${b}")
then :
else if [ $? -gt 1 ]
  then
    printf ' - Something went wrong...\n'
    exit 1
  fi
fi

printf ' - Result: %d\n' "${r}"
