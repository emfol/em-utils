#include <stdio.h>
#include <stdlib.h>

static int string_starts_with(const char *target, const char *prefix)
{
  unsigned char t, p;
  if (target == NULL || prefix == NULL) return 0;
  while ((p = (unsigned char)*prefix) != '\0') {
    if ((t = (unsigned char)*target) == '\0' || t != p) return 0;
    ++prefix, ++target;
  }
  return 1;
}

int main(int argc, char **argv) {
  if (argc == 3 && string_starts_with(*(argv + 2), *(argv + 1))) return EXIT_SUCCESS;
  return EXIT_FAILURE;
}
