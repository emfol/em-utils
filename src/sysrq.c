#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define SYSRQ_FILEPATH "SYSRQ_FILEPATH"
#define DEFAULT_SYSRQ_FILEPATH "/proc/sys/kernel/sysrq"
#define ON "On"
#define OFF "Off"

static long int get_current_sysrq_value(void) {
  char *endptr, *sysrq_filepath, buf[16];
  long int rd_cnt, result = -1L;
  int err, fd = -1;

  sysrq_filepath = getenv(SYSRQ_FILEPATH);
  if (sysrq_filepath == NULL || strlen(sysrq_filepath) == 0UL) {
    sysrq_filepath = DEFAULT_SYSRQ_FILEPATH;
  }

  fd = open(sysrq_filepath, O_RDONLY, 0);
  if (fd < 0) {
    fprintf(
      stderr,
      " - [ERROR] Cannot open \"%s\": %s\n",
      sysrq_filepath,
      strerror(errno)
    );
    goto clean_exit;
  }

  fprintf(
    stderr,
    " - [INFO] File successfully opened: %s\n",
    sysrq_filepath
  );

  /* The sysrq file ends with a '\n' char so at least 2 bytes must be read. */
  while ((rd_cnt = (long int)read(fd, buf, sizeof buf)) < 2L) {
    if (rd_cnt < 0L) {
      err = errno;
      if (err == EINTR) {
        fputs(
          " - [INFO] Interrupted by signal! Retying...\n",
          stderr
        );
        continue;
      }
      fprintf(
        stderr,
        " - [ERROR] Error reading contents of sysrq file: %s\n",
        strerror(err)
      );
    } else {
      fputs(
        " - [ERROR] Empty sysrq file! Nothing to do...\n",
        stderr
      );
    }
    goto clean_exit;
  }

  if (rd_cnt > 10) {
    fprintf(
      stderr,
      " - [ERROR] Unexpected length for sysrq contents: %ld\n",
      rd_cnt
    );
    goto clean_exit;
  }

  /* Make sure the last character of the string is a '\n' char. */
  endptr = buf + (rd_cnt - 1L);
  if (*endptr != '\n') {
    fprintf(
      stderr,
      " - [ERROR] The sysrq contents should end with a new-line. Got: %c\n",
      *endptr
    );
    goto clean_exit;
  }

  /* Replace the final new-line with a null byte. */
  *endptr = '\0';
  result = strtol(buf, &endptr, 10);
  if (endptr > buf && *endptr == '\0' && *buf != '\0') {
    fprintf(
      stderr,
      " - [INFO] Current sysrq value: %ld\n",
      result
    );
  } else {
    result = -1L;
    fprintf(
      stderr,
      " - [ERROR] Invalid sysrq contents: %s\n",
      buf
    );
  }

  clean_exit:
  if (fd >= 0) {
    if (close(fd) == 0) {
      fprintf(
        stderr,
        " - [INFO] File successfully closed: %s\n",
        sysrq_filepath
      );
    } else {
      fprintf(
        stderr,
        " - [ERROR] Error closing file: \"%s\" (%s)\n",
        sysrq_filepath,
        strerror(errno)
      );
    }
  }
  return result;
}

static void parse_sysrq_value(long int value) {
  static struct sysrq_mask_table_entry {
    int mask;
    const char *description;
  } *entry, sysrq_mask_table[] = {
    { 0x002, "Enable control of console logging level" },
    { 0x004, "Enable control of keyboard (SAK, unraw)" },
    { 0x008, "Enable debugging dumps of processes etc." },
    { 0x010, "Enable sync command" },
    { 0x020, "Enable remount read-only" },
    { 0x040, "Enable signalling of processes (term, kill, oom-kill)" },
    { 0x080, "Allow reboot/poweroff" },
    { 0x100, "Allow nicing of all RT tasks" },
  };
  const char *flag;
  register long int mask;
  int i;
  fprintf(
    stdout,
    " @ Current sysrq value: %ld\n"
    " @ Active functions:\n",
    value
  );
  for (i = 0; i < (int)(sizeof sysrq_mask_table / sizeof(struct sysrq_mask_table_entry)); ++i) {
    entry = sysrq_mask_table + i;
    mask = entry->mask;
    if ((value & mask) != 0L) {
      value ^= mask;
      flag = ON;
    } else {
      flag = (value & 1L) == 1L ? ON : OFF;
    }
    fprintf(
      stdout,
      "   - %03ld. (0x%03lx) %s: %s\n",
      mask,
      (unsigned long int)mask,
      entry->description,
      flag
    );
  }
  if (value > 1) {
    fprintf(
      stderr,
      " - [WARN] Unknown flags: %ld (0x%04lx)\n",
      value,
      (unsigned long int)value
    );
  }
}

int main(void) {
  long int sysrq_value = get_current_sysrq_value();
  if (sysrq_value < 0) return 1;
  parse_sysrq_value(sysrq_value);
  return 0;
}
