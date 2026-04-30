.PHONY: all clean

CC := gcc

# Base safe flags
CFLAGS := -O2 -flto -std=c11 -Wall -Wextra -pedantic -march=native


tools := \
	gfx \
	make_patch \
	pkmncompress \
	scan_includes

all: $(tools)
	@:

clean:
	$(RM) $(tools)

gfx: common.h
scan_includes: common.h

%: %.c
	$(CC) $(CFLAGS) -o $@ $<