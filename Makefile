CFLAGS := -std=c89 -pedantic -Wall -g -D_XOPEN_SOURCE=600
BINARIES := bin/args bin/bcs bin/starts_with bin/cstr2bin bin/sysrq

$(shell test ! -e ./bin && mkdir -p bin)

.PHONY: clean test

all: $(BINARIES)

bin/shared.o: src/shared.c
	cc $(CFLAGS) -o $@ -c $<

bin/args: src/args.c
	cc $(CFLAGS) -o $@ $<

bin/bcs: src/bcs.c
	cc $(CFLAGS) -o $@ $<

bin/starts_with: src/starts_with.c bin/shared.o
	cc $(CFLAGS) -o $@ $^

bin/cstr2bin: src/cstr2bin.c
	cc $(CFLAGS) -o $@ $<

bin/sysrq: src/sysrq.c
	cc $(CFLAGS) -o $@ $<

test: $(BINARIES)
	./scripts/test.sh

clean:
	rm -rf $(BINARIES) bin/*.o
