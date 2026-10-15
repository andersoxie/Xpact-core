note
	description: "[
		Decodes managed pointer of ISO-8859-1 encoded text into UTF-8 character array skipping CR characters
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-08-06 07:48:00 GMT (Thursday 30th August 2026)"
	revision: "1"

class
	XT_LATIN_1_CODEC

inherit
	EL_MANAGED_C_STRING_8
		export
			{XT_C_STRING_CODEC} area
			{STRING_HANDLER} make_shared
			{NONE} all
		end

	XT_C_STRING_CODEC
		undefine
			copy, is_equal
		end

create
	make, make_shared, make_from_string, make_empty, make_filled

feature -- Access

	encoding: INTEGER
		do
			Result := Latin_1
		end

feature -- Basic operations

	copy_as_utf_8 (dest: SPECIAL [CHARACTER]; dest_index, n: INTEGER)
		local
			dest_full: BOOLEAN; ptr: POINTER; c_i: CHARACTER
			i, i_final, j, remaining_count: INTEGER
		do
			ptr := area; i_final := count - 1
			remaining_count := n
			from i := 0; j := dest_index until i > i_final or dest_full loop
				c_i := c_read_character_8 (ptr, i)
				inspect c_i when '%R' then
				-- skip '%R'
					i := i + 1
				else
					if c_i < '%/128/' then
						inspect remaining_count when 0 then
							dest_full := True
						else
							dest [j] := c_i
							j := j + 1
							remaining_count := remaining_count - 1
							i := i + 1
						end
					else
						inspect remaining_count when 0, 1 then
							dest_full := True
						else
							dest [j] := (0xC0 | (c_i.code |>> 6)).to_character_8
							dest [j + 1] := (0x80 | (c_i.code & 0x3F)).to_character_8
							j := j + 2
							remaining_count := remaining_count - 2
							i := i + 1
						end
					end
				end
			end
			utf_8_copied_count := n - remaining_count
			last_index := i
			set_utf_8_to_count_ratio
		end

feature {NONE} -- Constants

	Code_unit_bytes: INTEGER = 1
end
