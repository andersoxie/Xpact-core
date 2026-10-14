note
	description: "UTF-8 validation routines"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-08-15 08:40:00 GMT (Saturday 15th August 2026)"
	revision: "1"

class
	XT_UTF_8_VALIDATION

inherit
	XT_BYTE_TYPE_CONSTANTS
		export
			{NONE} all
		end

feature -- Name-character predicates

	is_invalid_character (buf: SPECIAL [CHARACTER]; index, byte_count: INTEGER): BOOLEAN
		do
			inspect byte_count
				when 2 then
					Result := is_invalid_char_2 (buf, index)
				when 3 then
					Result := is_invalid_char_3 (buf, index)
				when 4 then
					Result := is_invalid_char_4 (buf, index)
			else
				Result := False
			end
		end

	is_name_start_character (buf: SPECIAL [CHARACTER]; index, byte_count: INTEGER): BOOLEAN
		do
			inspect byte_count
				when 2 then
					Result := is_name_start_char_2 (buf, index)
				when 3 then
					Result := is_name_start_char_3 (buf, index)
				when 4 then
					Result := is_name_start_char_4 (buf, index)
			else
				Result := False
			end
		end

	is_name_character (buf: SPECIAL [CHARACTER]; index, byte_count: INTEGER): BOOLEAN
		do
			inspect byte_count
				when 2 then
					Result := is_name_char_2 (buf, index)
				when 3 then
					Result := is_name_char_3 (buf, index)
				when 4 then
					Result := is_name_char_4 (buf, index)
			else
				Result := False
			end
		end

feature -- Name-character predicates (2-byte UTF-8, U+0080..U+07FF)

	is_name_char_2 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- Is the 2-byte sequence at index a valid XML NameChar?
			-- Uses namePages and the naming bitmap.
		require
			valid_index: index + 1 < buf.count
		local
			b0, b1, pg, idx: INTEGER
		do
			b0 := buf [index].code
			b1 := buf [index + 1].code
			pg := name_pages [(b0 |>> 2) & 7].to_integer_32
			idx := (pg |<< 3) + ((b0 & 3) |<< 1) + ((b1 |>> 5) & 1)
			Result := (Naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b1 & 0x1F))) /= 0
		end

	is_name_start_char_2 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- Is the 2-byte sequence at index a valid XML NameStartChar?
			-- Uses nmstrtPages and the naming bitmap.
		require
			valid_index: index + 1 < buf.count
		local
			b0, b1, pg, idx: INTEGER
		do
			b0 := buf [index].code
			b1 := buf [index + 1].code
			pg := Name_start_pages [(b0 |>> 2) & 7].to_integer_32
			idx := (pg |<< 3) + ((b0 & 3) |<< 1) + ((b1 |>> 5) & 1)
			Result := (Naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b1 & 0x1F))) /= 0
		end

	is_invalid_char_2 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- True for overlong sequences (b0 = 0xC0 or 0xC1 code points U+0000..U+007F).
			-- The byte table maps 0xC0-0xDF all to BT_lead_2_byte; this check catches the two
			-- overlong lead bytes that the table does not exclude.
		require
			valid_index: index + 1 < buf.count
		local
			b1: INTEGER
		do
			b1 := buf [index + 1].code
			Result := buf [index].code < 0xC2 or else (b1 & 0x80) = 0 or else (b1 & 0xC0) = 0xC0
		end

feature -- Name-character predicates (3-byte UTF-8, U+0800..U+FFFF)

	is_name_char_3 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- Is the 3-byte sequence at index a valid XML NameChar?
		require
			valid_index: index + 2 < buf.count
		local
			b0, b1, b2, pg, idx: INTEGER
		do
			b0 := buf [index].code
			b1 := buf [index + 1].code
			b2 := buf [index + 2].code
			pg := name_pages [((b0 & 0xF) |<< 4) + ((b1 |>> 2) & 0xF)].to_integer_32
			idx := (pg |<< 3) + ((b1 & 3) |<< 1) + ((b2 |>> 5) & 1)
			Result := (Naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b2 & 0x1F))) /= 0
		end

	is_name_start_char_3 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- Is the 3-byte sequence at index a valid XML NameStartChar?
		require
			valid_index: index + 2 < buf.count
		local
			b0, b1, b2, pg, idx: INTEGER
		do
			b0 := buf [index].code
			b1 := buf [index + 1].code
			b2 := buf [index + 2].code
			pg := Name_start_pages [((b0 & 0xF) |<< 4) + ((b1 |>> 2) & 0xF)].to_integer_32
			idx := (pg |<< 3) + ((b1 & 3) |<< 1) + ((b2 |>> 5) & 1)
			Result := (Naming_bitmap [idx] & ({NATURAL_32} 1 |<< (b2 & 0x1F))) /= 0
		end

	is_invalid_char_3 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
		require
			valid_index: index + 2 < buf.count
		local
			b0, b1, b2: INTEGER
		do
			b0 := buf [index].code; b1 := buf [index + 1].code; b2 := buf [index + 2].code
			inspect b2 & 0x80 when 0 then
				Result := True
			else
				if b0 = 0xEF and b1 = 0xBF then
					Result := b2 > 0xBD
				elseif (b2 & 0xC0) = 0xC0 then
					Result := True
				end
			end
			if not Result then
				inspect b0 when 0xE0 then
					Result := b1 < 0xA0 or (b1 & 0xC0) = 0xC0
				else
					if (b1 & 0x80) = 0 then
						Result := True
					elseif b0 = 0xED then
						Result := b1 > 0x9F
					else
						Result := (b1 & 0xC0) = 0xC0
					end
				end
			end
		end

feature -- Name-character predicates (4-byte UTF-8, U+10000..U+10FFFF)

	is_name_char_4 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- 4-byte characters are not NameChars in XML 1.0.
		require
			valid_index: index + 3 < buf.count
		do
			Result := False
		end

	is_name_start_char_4 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
			-- 4-byte characters are not NameStartChars in XML 1.0.
		require
			valid_index: index + 3 < buf.count
		do
			Result := False
		end

	is_invalid_char_4 (buf: SPECIAL [CHARACTER]; index: INTEGER): BOOLEAN
		require
			valid_index: index + 3 < buf.count
		local
			b0, b1, b2, b3: INTEGER
		do
			b0 := buf [index].code; b1 := buf [index + 1].code
			b2 := buf [index + 2].code; b3 := buf [index + 3].code
			if (b3 & 0x80) = 0 or (b3 & 0xC0) = 0xC0 or (b2 & 0x80) = 0 or (b2 & 0xC0) = 0xC0 then
				Result := True
			elseif b0 = 0xF0 then
				Result := b1 < 0x90 or (b1 & 0xC0) = 0xC0
			elseif (b1 & 0x80) = 0 then
				Result := True
			elseif b0 = 0xF4 then
				Result := b1 > 0x8F
			else
				Result := (b1 & 0xC0) = 0xC0
			end
		end

feature -- Naming tables

	Naming_bitmap: SPECIAL [NATURAL_32]
		-- namingBitmap[] from nametab.h.
		once
			Result := ({ARRAY [NATURAL_32]} <<
				0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0xFFFFFFFF, 0xFFFFFFFF,
				0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
				0xFFFFFFFF, 0x00000000, 0x04000000, 0x87FFFFFE, 0x07FFFFFE,
				0x00000000, 0x00000000, 0xFF7FFFFF, 0xFF7FFFFF, 0xFFFFFFFF,
				0x7FF3FFFF, 0xFFFFFDFE, 0x7FFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
				0xFFFFE00F, 0xFC31FFFF, 0x00FFFFFF, 0x00000000, 0xFFFF0000,
				0xFFFFFFFF, 0xFFFFFFFF, 0xF80001FF, 0x00000003, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xFFFFD740,
				0xFFFFFFFB, 0x547F7FFF, 0x000FFFFD, 0xFFFFDFFE, 0xFFFFFFFF,
				0xDFFEFFFF, 0xFFFFFFFF, 0xFFFF0003, 0xFFFFFFFF, 0xFFFF199F,
				0x033FCFFF, 0x00000000, 0xFFFE0000, 0x027FFFFF, 0xFFFFFFFE,
				0x0000007F, 0x00000000, 0xFFFF0000, 0x000707FF, 0x00000000,
				0x07FFFFFE, 0x000007FE, 0xFFFE0000, 0xFFFFFFFF, 0x7CFFFFFF,
				0x002F7FFF, 0x00000060, 0xFFFFFFE0, 0x23FFFFFF, 0xFF000000,
				0x00000003, 0xFFF99FE0, 0x03C5FDFF, 0xB0000000, 0x00030003,
				0xFFF987E0, 0x036DFDFF, 0x5E000000, 0x001C0000, 0xFFFBAFE0,
				0x23EDFDFF, 0x00000000, 0x00000001, 0xFFF99FE0, 0x23CDFDFF,
				0xB0000000, 0x00000003, 0xD63DC7E0, 0x03BFC718, 0x00000000,
				0x00000000, 0xFFFDDFE0, 0x03EFFDFF, 0x00000000, 0x00000003,
				0xFFFDDFE0, 0x03EFFDFF, 0x40000000, 0x00000003, 0xFFFDDFE0,
				0x03FFFDFF, 0x00000000, 0x00000003, 0x00000000, 0x00000000,
				0x00000000, 0x00000000, 0xFFFFFFFE, 0x000D7FFF, 0x0000003F,
				0x00000000, 0xFEF02596, 0x200D6CAE, 0x0000001F, 0x00000000,
				0x00000000, 0x00000000, 0xFFFFFEFF, 0x000003FF, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0xFFFFFFFF, 0xFFFF003F,
				0x007FFFFF, 0x0007DAED, 0x50000000, 0x82315001, 0x002C62AB,
				0x40000000, 0xF580C900, 0x00000007, 0x02010800, 0xFFFFFFFF,
				0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0x0FFFFFFF, 0xFFFFFFFF,
				0xFFFFFFFF, 0x03FFFFFF, 0x3F3FFFFF, 0xFFFFFFFF, 0xAAFF3F3F,
				0x3FFFFFFF, 0xFFFFFFFF, 0x5FDFFFFF, 0x0FCF1FDC, 0x1FDC1FFF,
				0x00000000, 0x00004C40, 0x00000000, 0x00000000, 0x00000007,
				0x00000000, 0x00000000, 0x00000000, 0x00000080, 0x000003FE,
				0xFFFFFFFE, 0xFFFFFFFF, 0x001FFFFF, 0xFFFFFFFE, 0xFFFFFFFF,
				0x07FFFFFF, 0xFFFFFFE0, 0x00001FFF, 0x00000000, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xFFFFFFFF,
				0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0x0000003F,
				0x00000000, 0x00000000, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
				0xFFFFFFFF, 0xFFFFFFFF, 0x0000000F, 0x00000000, 0x00000000,
				0x00000000, 0x07FF6000, 0x87FFFFFE, 0x07FFFFFE, 0x00000000,
				0x00800000, 0xFF7FFFFF, 0xFF7FFFFF, 0x00FFFFFF, 0x00000000,
				0xFFFF0000, 0xFFFFFFFF, 0xFFFFFFFF, 0xF80001FF, 0x00030003,
				0x00000000, 0xFFFFFFFF, 0xFFFFFFFF, 0x0000003F, 0x00000003,
				0xFFFFD7C0, 0xFFFFFFFB, 0x547F7FFF, 0x000FFFFD, 0xFFFFDFFE,
				0xFFFFFFFF, 0xDFFEFFFF, 0xFFFFFFFF, 0xFFFF007B, 0xFFFFFFFF,
				0xFFFF199F, 0x033FCFFF, 0x00000000, 0xFFFE0000, 0x027FFFFF,
				0xFFFFFFFE, 0xFFFE007F, 0xBBFFFFFB, 0xFFFF0016, 0x000707FF,
				0x00000000, 0x07FFFFFE, 0x0007FFFF, 0xFFFF03FF, 0xFFFFFFFF,
				0x7CFFFFFF, 0xFFEF7FFF, 0x03FF3DFF, 0xFFFFFFEE, 0xF3FFFFFF,
				0xFF1E3FFF, 0x0000FFCF, 0xFFF99FEE, 0xD3C5FDFF, 0xB080399F,
				0x0003FFCF, 0xFFF987E4, 0xD36DFDFF, 0x5E003987, 0x001FFFC0,
				0xFFFBAFEE, 0xF3EDFDFF, 0x00003BBF, 0x0000FFC1, 0xFFF99FEE,
				0xF3CDFDFF, 0xB0C0398F, 0x0000FFC3, 0xD63DC7EC, 0xC3BFC718,
				0x00803DC7, 0x0000FF80, 0xFFFDDFEE, 0xC3EFFDFF, 0x00603DDF,
				0x0000FFC3, 0xFFFDDFEC, 0xC3EFFDFF, 0x40603DDF, 0x0000FFC3,
				0xFFFDDFEC, 0xC3FFFDFF, 0x00803DCF, 0x0000FFC3, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0xFFFFFFFE, 0x07FF7FFF,
				0x03FF7FFF, 0x00000000, 0xFEF02596, 0x3BFF6CAE, 0x03FF3F5F,
				0x00000000, 0x03000000, 0xC2A003FF, 0xFFFFFEFF, 0xFFFE03FF,
				0xFEBF0FDF, 0x02FE3FFF, 0x00000000, 0x00000000, 0x00000000,
				0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
				0x1FFF0000, 0x00000002, 0x000000A0, 0x003EFFFE, 0xFFFFFFFE,
				0xFFFFFFFF, 0x661FFFFF, 0xFFFFFFFE, 0xFFFFFFFF, 0x77FFFFFF
			>>).area
		end

	Name_start_pages: SPECIAL [NATURAL_8]
			-- nmstrtPages[] from nametab.h (256 entries).
		once
			create Result.make_filled (0, 256)
			if attached Result as t then
				t [ 0] := 0x02; t [ 1] := 0x03; t [ 2] := 0x04; t [ 3] := 0x05
				t [ 4] := 0x06; t [ 5] := 0x07; t [ 6] := 0x08; t [ 7] := 0x00
				t [ 8] := 0x00; t [ 9] := 0x09; t [10] := 0x0A; t [11] := 0x0B
				t [12] := 0x0C; t [13] := 0x0D; t [14] := 0x0E; t [15] := 0x0F
				t [16] := 0x10; t [17] := 0x11; t [30] := 0x12; t [31] := 0x13
				t [33] := 0x14; t [48] := 0x15; t [49] := 0x16
				Result.fill_with (0x01, 78, 158)
				t [159] := 0x17
				Result.fill_with (0x01, 172, 214)
				t [215] := 0x18
			end
		end

	Name_pages: SPECIAL [NATURAL_8]
			-- namePages[] from nametab.h (256 entries).
		once
			create Result.make_filled (0, 256)
			if attached Result as t then
				t [ 0] := 0x19; t [ 1] := 0x03; t [ 2] := 0x1A; t [ 3] := 0x1B
				t [ 4] := 0x1C; t [ 5] := 0x1D; t [ 6] := 0x1E; t [ 9] := 0x1F
				t [10] := 0x20; t [11] := 0x21; t [12] := 0x22; t [13] := 0x23
				t [14] := 0x24; t [15] := 0x25; t [16] := 0x10; t [17] := 0x11
				t [30] := 0x12; t [31] := 0x13; t [32] := 0x26; t [33] := 0x14
				t [48] := 0x27; t [49] := 0x16
				Result.fill_with (0x01, 78, 158)
				t [159] := 0x17
				Result.fill_with (0x01, 172, 214)
				t [215] := 0x18
			end
		end

end
