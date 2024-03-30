#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define DEFAULT_BLOCK_SIZE (4096L)
#define IEC_BUFFER_SIZE (32)
#define DEFAULT_MAX_CHUNK_SIZE (DEFAULT_BLOCK_SIZE * 1024L)

struct options {
  const char *file_path;
  long int block_size;
  long int max_chunk_size;
  int verbose;
};

struct IEC_unit {
  const char *unit;
  long int value;
};

static int get_IEC_representation(long int value, char *buffer, int limit)
{
  static struct IEC_unit IEC_units[] = {
    { "GiB", 0x40000000L },
    { "MiB", 0x100000L },
    { "KiB", 0x400L },
    { "B", 0x1L }
  };
  struct IEC_unit *unit = NULL;
  int i;
  for (i = 0; i < sizeof IEC_units / sizeof (struct IEC_unit); ++i) {
    unit = IEC_units + i;
    if (value >= unit->value) break;
  }
  return snprintf(buffer, (size_t)limit, "%.2f %s", ((double)value / (double)unit->value), unit->unit);
}

static long int get_file_size(const char *file_path)
{
  struct stat s;
  int r;
  r = stat(file_path, &s);
  if (r != 0) return -1L;
  return (long int)s.st_size;
}

static long int get_best_chunk_size(long int block_size, long int max_chunk_size, long int file_size)
{
  long int blocks, max_blocks;

  if (block_size <= 0L
      || file_size < block_size
      || max_chunk_size < block_size
      || (file_size % block_size) != 0L
      || (max_chunk_size % block_size) != 0L) return -1L;

  blocks = file_size / block_size;
  max_blocks = max_chunk_size / block_size;

  if (blocks <= max_blocks) return blocks * block_size;

  while ((blocks % max_blocks) != 0L) --max_blocks;

  return max_blocks * block_size;
}

static void print_usage(const char *command)
{
  fprintf(
    stderr,
    "\nUsage:\n\t"
    "%s [-v] [-b block_size] [-m max_chunk_size] file_path\n\n",
    command
  );
}

static int get_options(int argc, char *const *argv, struct options *options)
{
  extern char *optarg;
  extern int optind, optopt;
  int opt, errors = 0;

  /* Make sure the given options structure is properly intialized. */
  options->file_path = NULL;
  options->block_size = DEFAULT_BLOCK_SIZE;
  options->max_chunk_size = DEFAULT_MAX_CHUNK_SIZE;
  options->verbose = 0;

  /* Iterate through options. */
  while ((opt = getopt(argc, argv, ":vb:m:")) != -1) {
    switch (opt) {
      case 'v':
        options->verbose = 1;
        break;
      case 'b':
        options->block_size = strtol(optarg, NULL, 0);
        break;
      case 'm':
        options->max_chunk_size = strtol(optarg, NULL, 0);
        break;
      case ':':
        fprintf(stderr, " > Option \"-%c\" requires an argument.\n", optopt);
        ++errors;
        break;
      case '?':
        fprintf(stderr, " > Unrecognized option: \"-%c\".\n", optopt);
        ++errors;
        break;
    }
  }

  /* Fail if too few or too many arguments are provided. */
  if (optind != argc - 1) {
    fputs(" > One file path is expected.\n", stderr);
    ++errors;
  }

  /* Abort if any error is reported. */
  if (errors != 0) return 0;

  /* Use the last argument as the file path. */
  options->file_path = *(argv + optind);

  return 1;
}

int main(int argc, char *const *argv)
{
  long int file_size, best_chunk_size;
  struct options options;
  char file_size_iec[IEC_BUFFER_SIZE],
       best_chunk_size_iec[IEC_BUFFER_SIZE],
       block_size_iec[IEC_BUFFER_SIZE],
       max_chunk_size_iec[IEC_BUFFER_SIZE];

  if (!get_options(argc, argv, &options)) {
    print_usage(*argv);
    return EXIT_FAILURE;
  }

  file_size = get_file_size(options.file_path);
  if (file_size < 0) {
    fprintf(
      stderr,
      " > Error reading information from file: \"%s\" (%s)\n",
      options.file_path,
      strerror(errno)
    );
    return EXIT_FAILURE;
  }

  best_chunk_size = get_best_chunk_size(options.block_size, options.max_chunk_size, file_size);

  if (best_chunk_size <= 0) {
    fprintf(
      stderr,
      " > Incompatible values for block, max chunk and file sizes: %ld, %ld, %ld.\n",
      options.block_size, options.max_chunk_size, file_size
    );
    return EXIT_FAILURE;
  }

  get_IEC_representation(file_size, file_size_iec, IEC_BUFFER_SIZE);
  get_IEC_representation(best_chunk_size, best_chunk_size_iec, IEC_BUFFER_SIZE);
  get_IEC_representation(options.block_size, block_size_iec, IEC_BUFFER_SIZE);
  get_IEC_representation(options.max_chunk_size, max_chunk_size_iec, IEC_BUFFER_SIZE);

  if (options.verbose) {
    printf(
      "File Size: %ld (%s)\n"
      "Block Size: %ld (%s)\n"
      "Max Chunk Size: %ld (%s)\n"
      "Best Chunk Size: %ld (%s)\n"
      "Number of Chunks in File: %ld\n"
      "Number of Blocks per Chunk: %ld\n",
      file_size,
      file_size_iec,
      options.block_size,
      block_size_iec,
      options.max_chunk_size,
      max_chunk_size_iec,
      best_chunk_size,
      best_chunk_size_iec,
      file_size / best_chunk_size,
      best_chunk_size / options.block_size
    );
  } else {
    printf(
      "File Size: %ld\n"
      "Best Chunk Size: %ld\n",
      file_size,
      best_chunk_size
    );
  }

  return EXIT_SUCCESS;
}
