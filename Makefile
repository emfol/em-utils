CFLAGS := -std=c89 -pedantic -Wall -g -D_XOPEN_SOURCE=600
BINARIES := bin/bcs bin/starts_with

$(shell test ! -e ./bin && mkdir -p bin)

.PHONY: clean

all: $(BINARIES)

bin/bcs: src/bcs.c
	cc $(CFLAGS) -o $@ $<

bin/starts_with: src/starts_with.c
	cc $(CFLAGS) -o $@ $<

clean:
	rm -rf $(BINARIES)
