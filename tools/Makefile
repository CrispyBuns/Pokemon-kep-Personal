.PHONY: all clean

CC := gcc

# Base safe flags
CFLAGS := -O2 -flto -std=c11 -Wall -Wextra -pedantic -msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx2 -mfma -mbmi -mbmi2


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
