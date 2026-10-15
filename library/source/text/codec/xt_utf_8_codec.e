note
	description: "[
		Copies managed pointer of UTF-8 encoded text into UTF-8 character array skipping CR characters
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-07-30 11:43:00 GMT (Thursday 30th July 2026)"
	revision: "1"

class
	XT_UTF_8_CODEC

inherit
	XT_LATIN_1_CODEC
		redefine
			copy_as_utf_8, encoding
		end

create
	make, make_shared, make_empty, make_from_string

feature -- Access

	encoding: INTEGER
		do
			Result := UTF_8
		end

feature -- Basic operations

	copy_as_utf_8 (dest: SPECIAL [CHARACTER]; dest_index, n: INTEGER)
		local
			ptr: POINTER; i, j, i_final: INTEGER; c: CHARACTER
		do
			ptr := area; i_final := count.min (n) - 1
			i := 0; j := dest_index
			if pending_CR then
			-- The last chunked ended with a CR
				inspect c_read_character_8 (ptr, i) when '%N' then
					do_nothing
				else
				-- replace isolated '%R' with '%N'
					dest [j] := '%N'
					i_final := i_final - 1 -- reduce the number of remaining characters
					j := j + 1
				end
				pending_CR := False
			end
			from until i > i_final loop
				c := c_read_character_8 (ptr, i)
				inspect c when '%R' then
					i := i + 1 -- skip '%R'
					if i > i_final then
					-- find out in next chunk if characters is Newline
						pending_CR := True
					else
						inspect c_read_character_8 (ptr, i) when '%N' then
							do_nothing
						else
						-- replace isolated '%R' with '%N'
							dest [j] := '%N'
							j := j + 1
						end
					end
				else
					dest [j] := c
					j := j + 1
					i := i + 1
				end
			end
			last_index := i
			utf_8_copied_count := j - dest_index
			set_utf_8_to_count_ratio
		end

end
