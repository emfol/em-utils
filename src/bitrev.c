#include <stdlib.h>
#include <stdio.h>
#include "shared.h"

static unsigned long int reverse_bits(register unsigned long int pattern) {
  register unsigned long int reverse = 0;
  while (pattern) {
    reverse = reverse << 1 | pattern & 1;
    pattern >>= 1;
  }
  return reverse;
}

int main(void) {
  return 0;
}
