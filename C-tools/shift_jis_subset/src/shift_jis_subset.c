#include "shift_jis_subset.h"
#include <stdlib.h>

/* Mirrors the layout of <expat.h>'s XML_Encoding struct (and Xpact's own,
 * field-for-field identical, struct in <xpact.h>) without depending on
 * either header -- see shift_jis_subset.h for why. */
struct xml_encoding_shape {
	int map[256];
	void *data;
	int (*convert)(void *data, const char *s);
	void (*release)(void *data);
};

/* Shift_JIS lead byte, trail byte, Unicode codepoint -- one entry per
 * distinct double-byte character used in 'tools/data/encoding-Shift_JIS_subset.xml'.
 	Sorted ascending by (lead, trail),
 * i.e. by the combined 16-bit key (lead << 8 | trail) built in
 * shift_jis_subset_fill_encoding, so shift_jis_subset_convert can
 * binary-search it. */
static const struct { unsigned char lead, trail; unsigned short codepoint; } raw_table[] = {
	{0x81, 0x5B, 0x30FC}, /* ー */
	{0x82, 0xCC, 0x306E}, /* の */
	{0x82, 0xE0, 0x3082}, /* も */
	{0x82, 0xE8, 0x308A}, /* り */
	{0x83, 0x42, 0x30A3}, /* ィ */
	{0x83, 0x47, 0x30A8}, /* エ */
	{0x83, 0x52, 0x30B3}, /* コ */
	{0x83, 0x54, 0x30B5}, /* サ */
	{0x83, 0x58, 0x30B9}, /* ス */
	{0x83, 0x5E, 0x30BF}, /* タ */
	{0x83, 0x66, 0x30C7}, /* デ */
	{0x83, 0x67, 0x30C8}, /* ト */
	{0x83, 0x68, 0x30C9}, /* ド */
	{0x83, 0x76, 0x30D7}, /* プ */
	{0x83, 0x8A, 0x30EA}, /* リ */
	{0x83, 0x8B, 0x30EB}, /* ル */
	{0x83, 0x93, 0x30F3}, /* ン */
	{0x8A, 0xC7, 0x7BA1}, /* 管 */
	{0x8A, 0xEE, 0x57FA}, /* 基 */
	{0x8B, 0x40, 0x6A5F}, /* 機 */
	{0x8B, 0xA3, 0x7AF6}, /* 競 */
	{0x8B, 0xC6, 0x696D}, /* 業 */
	{0x8C, 0x8E, 0x6708}, /* 月 */
	{0x8C, 0xA9, 0x898B}, /* 見 */
	{0x8D, 0x48, 0x5DE5}, /* 工 */
	{0x8D, 0x80, 0x9805}, /* 項 */
	{0x8D, 0x87, 0x5408}, /* 合 */
	{0x8D, 0x90, 0x544A}, /* 告 */
	{0x8D, 0xB8, 0x67FB}, /* 査 */
	{0x8D, 0xEC, 0x4F5C}, /* 作 */
	{0x8E, 0x52, 0x5C71}, /* 山 */
	{0x8E, 0x64, 0x4ED5}, /* 仕 */
	{0x8E, 0x7B, 0x65BD}, /* 施 */
	{0x8E, 0x81, 0x6C0F}, /* 氏 */
	{0x8E, 0x96, 0x4E8B}, /* 事 */
	{0x8E, 0xC0, 0x5B9F}, /* 実 */
	{0x8E, 0xD0, 0x793E}, /* 社 */
	{0x8F, 0x54, 0x9031}, /* 週 */
	{0x90, 0x94, 0x6570}, /* 数 */
	{0x90, 0xAC, 0x6210}, /* 成 */
	{0x90, 0xBB, 0x88FD}, /* 製 */
	{0x90, 0xCF, 0x7A4D}, /* 積 */
	{0x90, 0xD1, 0x7E3E}, /* 績 */
	{0x91, 0xBC, 0x4ED6}, /* 他 */
	{0x91, 0xBE, 0x592A}, /* 太 */
	{0x92, 0xB2, 0x8ABF}, /* 調 */
	{0x92, 0xE8, 0x5B9A}, /* 定 */
	{0x93, 0x63, 0x7530}, /* 田 */
	{0x93, 0x78, 0x5EA6}, /* 度 */
	{0x93, 0x96, 0x5F53}, /* 当 */
	{0x94, 0x4E, 0x5E74}, /* 年 */
	{0x94, 0x5C, 0x80FD}, /* 能 */
	{0x95, 0x69, 0x54C1}, /* 品 */
	{0x95, 0xF1, 0x5831}, /* 報 */
	{0x96, 0x7B, 0x672C}, /* 本 */
	{0x96, 0xB1, 0x52D9}, /* 務 */
	{0x96, 0xBC, 0x540D}, /* 名 */
	{0x96, 0xDA, 0x76EE}, /* 目 */
	{0x97, 0x5C, 0x4E88}, /* 予 */
	{0x97, 0x6C, 0x69D8}, /* 様 */
	{0x97, 0x9D, 0x7406}, /* 理 */
	{0x98, 0x59, 0x90CE}, /* 郎 */
};

#define RAW_TABLE_COUNT (sizeof(raw_table) / sizeof(raw_table[0]))

/* One entry of the combined-key lookup table built by
 * shift_jis_subset_fill_encoding and installed as the XML_Encoding `data'
 * member; `key' combines a 2-byte sequence's lead and trail bytes, e.g.
 * {0x81,0x5B} -> 0x815B, {0x98,0x59} -> 0x9859. */
typedef struct {
	unsigned short key;
	unsigned short codepoint;
} entry_t;

/* XML_Encoding's `convert' callback: `s' points at the 2-byte sequence
 * whose lead byte was already marked -2 in `map' (see
 * shift_jis_subset_fill_encoding); `data' is the entry_t table it
 * allocated. Binary-searches for the combined lead/trail key and returns
 * the Unicode scalar value, or -1 for any sequence not in this subset --
 * unknown_isInvalid() (in libexpat's xmltok.c) treats a negative return
 * as a malformed character. */
static int shift_jis_subset_convert(void *data, const char *s) {
	const entry_t *table = (const entry_t *) data;
	unsigned short key
		= (unsigned short) (((unsigned char) s[0] << 8) | (unsigned char) s[1]);
	size_t lo = 0, hi = RAW_TABLE_COUNT;
	while (lo < hi) {
		size_t mid = lo + (hi - lo) / 2;
		if (table[mid].key < key)
			lo = mid + 1;
		else
			hi = mid;
	}
	if (lo < RAW_TABLE_COUNT && table[lo].key == key)
		return table[lo].codepoint;
	return -1;
}

/* XML_Encoding's `release' callback: frees the table allocated by
 * shift_jis_subset_fill_encoding. */
static void shift_jis_subset_release(void *data) {
	free(data);
}

int shift_jis_subset_fill_encoding(void *info_ptr) {
	struct xml_encoding_shape *info = (struct xml_encoding_shape *) info_ptr;
	entry_t *table;
	size_t i;

	table = (entry_t *) malloc(RAW_TABLE_COUNT * sizeof(entry_t));
	if (! table)
		return 0;
	for (i = 0; i < RAW_TABLE_COUNT; i++) {
		table[i].key
			= (unsigned short) ((raw_table[i].lead << 8) | raw_table[i].trail);
		table[i].codepoint = raw_table[i].codepoint;
	}

	for (i = 0; i < 128; i++)
		info->map[i] = (int) i;
	for (i = 128; i < 256; i++)
		info->map[i] = -1;
	for (i = 0; i < RAW_TABLE_COUNT; i++)
		info->map[raw_table[i].lead] = -2;

	info->data = table;
	info->convert = shift_jis_subset_convert;
	info->release = shift_jis_subset_release;
	return 1;
}
