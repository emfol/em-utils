#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

#define BINARY_OUTPUT (1 << 0)
#define REVERSE_BITS  (1 << 1)

static unsigned int reverse_bits(register unsigned int pattern, register unsigned int length) {
  register unsigned int reverse = 1;
  length = 1U << length;
  while (reverse < length) {
    reverse = (reverse << 1) | (pattern & 1);
    pattern >>= 1;
  }
  return (reverse & (length - 1));
}

static void reverse_bytes(unsigned char *base, int length) {
  unsigned char tmp, *end;
  if (length > 0) {
    for (end = base + (length - 1); base <= end; ++base, --end) {
      tmp = (unsigned char)reverse_bits(*base, CHAR_BIT);
      if (base != end) *base = (unsigned char)reverse_bits(*end, CHAR_BIT);
      *end = tmp;
    }
  }
}

static int xd2nib(register int digit) {
  if (digit >= '0' && digit <= '9') return digit - '0';
  if ((digit |= 32) >= 'a' && digit <= 'f') return digit - 'a' + 10;
  return -1;
}

static int cstrs2char(unsigned char **cur) {
  int nib, chr = -1;
  switch (*++*cur) {
    case 'n':
      chr = '\n';
      break;
    case 't':
      chr = '\t';
      break;
    case '\\':
      chr = '\\';
      break;
    case 'x':
      chr = 1;
      do {
        nib = xd2nib(*++*cur);
        if (nib < 0) {
          chr = -1;
          break;
        }
        chr = (chr << 4) | nib;
      } while (chr < 256);
      if (chr >= 0) chr &= 255;
      break;
  }
  return chr;
}

static int cstr2bin(unsigned char *src) {
  unsigned char *cur, *dst;
  int ch;
  for (cur = dst = src; (ch = *cur) != '\0'; ++cur) {
    if (ch == '\\') {
      ch = cstrs2char(&cur);
      if (ch < 0) return -1;
    }
    if (dst == cur) ++dst;
    else *dst++ = (unsigned char)ch;
  }
  return (int)(dst - src);
}

static int parse_arg(unsigned char *arg, int flags) {
  unsigned int octet;
  int i, count, length = cstr2bin(arg);
  if (length < 0) return 0;
  if ((flags & REVERSE_BITS) != 0) reverse_bytes(arg, length);
  if ((flags & BINARY_OUTPUT) != 0) {
    count = (int)fwrite(arg, 1, length, stdout);
    if (count != length) {
      fprintf(
        stderr,
        " - [ERROR] Only %d bytes out of %d were written to output...",
        count,
        length
      );
    }
  } else {
    for (i = 0; i < length; ++i) {
      octet = *(arg + i);
      /* Printable characters? */
      if (octet > 32 && octet < 127) fprintf(stdout, "%c", (int)octet);
      else fprintf(stdout, "\\x%02x", octet);
    }
    fputs("\n", stdout);
  }
  return 1;
}

int main(int argc, char **argv) {
  char *arg;
  int i, flags, result = 0;
  for (i = 1, flags = 0; i < argc; ++i) {
    arg = *(argv + i);
    if (arg != NULL) {
      if (strcmp(arg, "-b") == 0) {
        flags |= BINARY_OUTPUT;
        continue;
      }
      if (strcmp(arg, "-r") == 0) {
        flags |= REVERSE_BITS;
        continue;
      }
      if (!parse_arg((unsigned char *)arg, flags)) {
        result = 1;
        break;
      }
    }
  }
  return result;
}
