#ifndef SHIFT_JIS_SUBSET_H
#define SHIFT_JIS_SUBSET_H

#ifdef __cplusplus
extern "C" {
#endif

/* Fills in an XML_Encoding-shaped struct to decode exactly the double-byte
 * Shift_JIS characters used in the Japanese weekly-report sample
 * 'deepseek_xml_20261013_202352.xml' -- not the full Shift_JIS table.
 *
 * `info_ptr' must point at a struct laid out as:
 *
 *     int map[256];
 *     void *data;
 *     int (*convert) (void *data, const char *s);
 *     void (*release) (void *data);
 *
 * which is the layout of both libexpat's XML_Encoding (<expat.h>) and
 * Xpact's own, field-for-field identical, struct (<xpact.h>). This
 * library never includes either header and never names the struct type
 * itself -- only its layout -- which is what lets the same compiled
 * object be linked into a libexpat-based C program (such as
 * xml_crc_32.c) and into Xpact's own Eiffel-generated C, without either
 * project's own XML_Encoding type ever being visible here.
 *
 * On success, fills map[] (ASCII identity for 0x00-0x7F, -2 marking a
 * 2-byte lead byte for each lead byte used by this subset, -1/malformed
 * for every other byte), allocates a lookup table into data (keyed by
 * combining each 2-byte sequence's lead and trail bytes into one 16-bit
 * value, e.g. {0x81,0x5B} -> 0x815B), and installs convert/release to
 * look up and later free that table. Returns 1 on success, or 0 (leaving
 * the struct untouched) if the lookup table couldn't be allocated. */
int shift_jis_subset_fill_encoding(void *info_ptr);

#ifdef __cplusplus
}
#endif

#endif /* SHIFT_JIS_SUBSET_H */
