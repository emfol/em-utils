CFLAGS := -std=c89 -pedantic -Wall -O2 -g -D_XOPEN_SOURCE=600
BINARIES := bin/args bin/bcs bin/starts_with

$(shell test ! -e ./bin && mkdir -p bin)

.PHONY: clean test

all: $(BINARIES)

bin/args: src/args.c
	cc $(CFLAGS) -o $@ $<

bin/bcs: src/bcs.c
	cc $(CFLAGS) -o $@ $<

bin/starts_with: src/starts_with.c
	cc $(CFLAGS) -o $@ $<

test: $(BINARIES)
	./test

clean:
	rm -rf $(BINARIES)
