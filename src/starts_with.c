#include <stdio.h>
#include <stdlib.h>
#include "shared.h"

int main(int argc, char **argv) {
  if (argc == 3 && string_starts_with(*(argv + 2), *(argv + 1))) return EXIT_SUCCESS;
  return EXIT_FAILURE;
}
