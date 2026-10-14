CC      ?= cc
CFLAGS  ?= -Wall -Wextra -O2 -std=c11
LDLIBS  := $(shell pkg-config --libs expat 2>/dev/null || echo -lexpat)
CFLAGS  += $(shell pkg-config --cflags expat 2>/dev/null)

SJIS_DIR := ../shift_jis_subset
SJIS_LIB := $(SJIS_DIR)/lib/libshift_jis_subset.a
CFLAGS   += -I$(SJIS_DIR)/include

TARGET  := build/xml_crc_32
SRC     := src/xml_crc_32.c

.PHONY: all clean

all: $(TARGET)

$(SJIS_LIB): FORCE
	$(MAKE) -C $(SJIS_DIR)

$(TARGET): $(SRC) $(SJIS_LIB)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(SJIS_LIB) $(LDLIBS)

.PHONY: FORCE
FORCE:

clean:
	rm -f $(TARGET)
