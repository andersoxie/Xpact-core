CC      ?= cc
CFLAGS  ?= -Wall -Wextra -O2 -std=c11

LIB     := lib/libshift_jis_subset.a
OBJ     := build/shift_jis_subset.o
SRC     := src/shift_jis_subset.c
HDR     := include/shift_jis_subset.h

.PHONY: all clean

all: $(LIB)

$(OBJ): $(SRC) $(HDR) | build
	$(CC) $(CFLAGS) -Iinclude -c -o $@ $(SRC)

$(LIB): $(OBJ) | lib
	ar rcs $@ $(OBJ)

build:
	mkdir -p $@

lib:
	mkdir -p $@

clean:
	rm -rf build lib
