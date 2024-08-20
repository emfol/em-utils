#include <stdio.h>

int main(int argc, char **argv)
{
  int i;
  if (argc < 2) {
    fputs("No arguments given...\n", stderr);
    return 1;
  }

  for (i = 1; i < argc; ++i) {
    printf(" %02d. \"%s\"\n", i, *(argv + i));
  }

  return 0;
}
