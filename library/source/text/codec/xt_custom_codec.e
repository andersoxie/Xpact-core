note
	description: "[
		${XT_C_STRING_CODEC} that uses a client supplied custom character mapping defined by class
		interface ${XT_CUSTOM_ENCODING}.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-10-02 11:13:00 GMT (Saturday 2nd October 2026)"
	revision: "1"

class
	XT_CUSTOM_CODEC

inherit
	EL_MANAGED_C_STRING_8
		rename
			make as make_codec
		export
			{XT_C_STRING_CODEC} area
			{STRING_HANDLER} make_shared
			{NONE} all
		redefine
			make_codec, make_shared
		end

	XT_C_STRING_CODEC
		rename
			encoding as encoding_code
		undefine
			copy, is_equal
		end

	XT_C_ENCODING_STRUCT
		undefine
			copy, is_equal
		end

create
	make, make_codec, make_shared, make_empty, make_from_string

feature {NONE} -- Initialization

	make (chunk: XT_C_STRING_CODEC; a_encoding: XT_CUSTOM_ENCODING_I)
		do
			make_shared (chunk.area, chunk.count)
			encoding := a_encoding
		end

	make_shared (a_ptr: POINTER; n: INTEGER)
		do
			Precursor (a_ptr, n)
			encoding := Default_encoding
			create partial_code_unit.make_empty (3)
		end

	make_codec (n: INTEGER)
		do
			Precursor (n)
			encoding := Default_encoding
			create partial_code_unit.make_empty (3)
		end

feature -- Access

	encoding_code: INTEGER
		do
			Result := Unknown_encoding
		end

	partial_code_unit: SPECIAL [CHARACTER]
		-- raw bytes of a multi-byte sequence left incomplete at the end of the
		-- previously copied block, to be completed with bytes from the start
		-- of the next block; meaningless when `partial_code_unit_count' = 0

feature -- Basic operations

	copy_as_utf_8 (dest: SPECIAL [CHARACTER]; dest_index, n: INTEGER)
		-- copy character content in `area' to `dest' as UTF-8 by decoding each byte sequence in area to unicode
		-- with user defined `encoding'
		local
			i, i_final, j, remaining_count, code_i, byte_count: INTEGER
			dest_full, partial_sequence, cr_skipped: BOOLEAN
			ptr, encoding_ptr: POINTER; c_i: CHARACTER
		do
			encoding_ptr := encoding.self_ptr; ptr := area; i_final := count - 1
			remaining_count := n
			from i := 0; j := dest_index until i > i_final or dest_full or partial_sequence loop
				if i = 0 and then partial_code_unit.count > 0 then
				-- complete the code unit left over from the end of the previously copied block
					cr_skipped := False
					code_i := c_map_code (encoding_ptr, c_read_character_8 (partial_code_unit.base_address, 0).code)
					byte_count := code_i.opposite
					 if partial_code_unit.count + i_final + 1 < byte_count then
		          -- still not enough bytes even with the whole of this block
		            extend_partial_code_unit (0, i_final + 1)
		            partial_sequence := True
            	else
						byte_count := byte_count - partial_code_unit.count; -- bytes still needed, taken from `area'
            		extend_partial_code_unit (0, byte_count)
						code_i := c_bytes_to_unicode (encoding_ptr, partial_code_unit.base_address)
						partial_code_unit.wipe_out
					end
				else
					c_i := c_read_character_8 (ptr, i)
					inspect c_i when '%R' then
					-- skip '%R'
						i := i + 1
						cr_skipped := True
					else
						cr_skipped := False
						code_i := c_map_code (encoding_ptr, c_i.code)
						if code_i < 0 then
							byte_count := code_i.opposite
							if i + byte_count - 1 > i_final then
								partial_sequence := True
								extend_partial_code_unit (i, i_final - i + 1)
								i := i_final + 1
							else
								code_i := c_bytes_to_unicode (encoding_ptr, ptr + i)
							end
						else
							byte_count := 1
						end
					end
				end
				if cr_skipped or partial_sequence then
					do_nothing

				elseif code_i <= 0x7F then -- 0xxxxxxx
					inspect remaining_count when 0 then
						dest_full := True
					else
						dest [j] := c_i
						remaining_count := remaining_count - 1
						i := i + byte_count; j := j + 1
					end

				elseif code_i < 0x7FF then -- 110xxxxx 10xxxxxx
					inspect remaining_count when 0, 1 then
						dest_full := True
					else
						fill_2_bytes (dest, j, code_i)
						remaining_count := remaining_count - 2
						i := i + byte_count; j := j + 2
					end

				elseif code_i < 0xFFFF then -- 1110xxxx 10xxxxxx 10xxxxxx
					inspect remaining_count when 0, 1, 2 then
						dest_full := True
					else
						fill_3_bytes (dest, j, code_i)
						remaining_count := remaining_count - 3
						i := i + byte_count; j := j + 3
					end
				else
					inspect remaining_count when 0, 1, 2, 3 then
						dest_full := True
					else
					-- `code_i' <= 1FFFFF - there are no higher code points
					-- 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
						fill_4_bytes (dest, j, code_i)
						remaining_count := remaining_count - 4
						i := i + byte_count; j := j + 4
					end
				end
			end
			last_index := i
			utf_8_copied_count := j - dest_index
			set_utf_8_to_count_ratio
		end

feature {NONE} -- Implementation

	extend_partial_code_unit (index, byte_count: INTEGER)
		local
			i: INTEGER
		do
			from i := 0 until i = byte_count loop
				partial_code_unit.extend (c_read_character_8 (area, index + i))
				i := i + 1
			end
		end

	fill_2_bytes (dest: SPECIAL [CHARACTER]; index, code_unit: INTEGER)
		do
			dest [index] := ((code_unit |>> 6) | 0xC0).to_character_8
			dest [index + 1] := ((code_unit & 0x3F) | 0x80).to_character_8
		end

	fill_3_bytes (dest: SPECIAL [CHARACTER]; index, code_unit: INTEGER)
		do
			dest [index] := ((code_unit |>> 12) | 0xE0).to_character_8
			dest [index + 1] := (((code_unit |>> 6) & 0x3F) | 0x80).to_character_8
			dest [index + 2] := ((code_unit & 0x3F) | 0x80).to_character_8
		end

	fill_4_bytes (dest: SPECIAL [CHARACTER]; index, code_unit: INTEGER)
		do
			dest [index] := ((code_unit |>> 18) | 0xF0).to_character_8
			dest [index + 1] := (((code_unit |>> 12) & 0x3F) | 0x80).to_character_8
			dest [index + 2] := (((code_unit |>> 6) & 0x3F) | 0x80).to_character_8
			dest [index + 3] := ((code_unit & 0x3F) | 0x80).to_character_8
		end

feature {NONE} -- Internal attributes

	encoding: XT_CUSTOM_ENCODING_I

feature {NONE} -- Constants

	Code_unit_bytes: INTEGER = 1

	Default_encoding: XT_CUSTOM_ENCODING
		once
			create Result.make
		end
end
