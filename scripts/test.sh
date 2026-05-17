#!/bin/sh

set +o errexit
export GREP_OPTIONS=''

script="$0"
script_dir=$(CDPATH='' cd -- "$(dirname -- "${script}")" >/dev/null && pwd -P)
script="${script_dir}/$(basename -- "${script}")"
bin_dir=$(CDPATH='' cd -- "${script_dir}/../bin" && pwd -P)

export PATH="${bin_dir}:${PATH}"

f2kib_block='/tmp/2kib-blocks-file.zeros'
f4kib_block='/tmp/4kib-blocks-file.zeros'
tmp_files="${f2kib_block} ${f4kib_block}"

dd if=/dev/zero of="${f2kib_block}" bs=2048 count=8191 >/dev/null 2>&1
dd if=/dev/zero of="${f4kib_block}" bs=4096 count=8192 >/dev/null 2>&1

trap "rm -rf ${tmp_files}" EXIT

output=$(bcs -v "${f2kib_block}" 2>/dev/null)
test $? -ne 0 && echo OK || echo FAIL
test -z "${output}" && echo OK || echo FAIL

output=$(bcs -v -b 2048 "${f2kib_block}" 2>/dev/null)
test $? -eq 0 && echo OK || echo FAIL
test "X${output}" = "X2048 $((2048 * 8191))" && echo OK || echo FAIL

output=$(bcs -v "${f4kib_block}" 2>/dev/null)
test $? -eq 0 && echo OK || echo FAIL
test "${output}" = "4194304 $((4096 * 8192))" && echo OK || echo FAIL

output=$(bcs -v -b 2048 "${f4kib_block}" 2>/dev/null)
test $? -eq 0 && echo OK || echo FAIL
test "${output}" = "4194304 $((4096 * 8192))" && echo OK || echo FAIL

output=$(bcs -v -b 2047 "${f4kib_block}" 2>/dev/null)
test $? -ne 0 && echo OK || echo FAIL
test -z "${output}" && echo OK || echo FAIL

if ! bin/starts_with em ''
then echo OK
else echo FAIL
fi

if bin/starts_with em ema
then echo OK
else echo FAIL
fi

if ! bin/starts_with em Ema
then echo OK
else echo FAIL
fi

if bin/starts_with '' Ema
then echo OK
else echo FAIL
fi

if ! bin/starts_with a Ema
then echo OK
else echo FAIL
fi

if ! bin/starts_with e Ema
then echo OK
else echo FAIL
fi

if bin/starts_with 'E' Ema
then echo OK
else echo FAIL
fi

if bin/starts_with 'Ema' Ema
then echo OK
else echo FAIL
fi

if bin/starts_with Ema Ema
then echo OK
else echo FAIL
fi

if ! bin/starts_with Emax Ema
then echo OK
else echo FAIL
fi

if output=$(bin/cstr2bin -r '\x0f\x01' '\x0B\x07')
then
  if [ "${output}" = "$(printf '%s\n' '\x80\xf0' '\xe0\xd0')" ]
  then echo OK
  else echo FAIL
  fi
else echo FAIL
fi
