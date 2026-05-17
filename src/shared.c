#include "shared.h"

int string_starts_with(register const char *target, register const char *prefix) {
  register unsigned int ch;
  while ((ch = *prefix++) != '\0') if (*target++ != ch) return 0;
  return 1;
}
