note
	description: "[
		Decodes managed pointer of UTF-16 encoded text into UTF-8 character array skipping CR characters.
		Manages situation of partial code unit at end of string and assumes next `make_shared' cal will
		supply the missing code unit.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-07-30 07:48:00 GMT (Thursday 30th July 2026)"
	revision: "1"
class
	XT_UTF_16_LE_CODEC

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

	EL_EIFFEL_C_API
		undefine
			copy, is_equal
		end

create
	make, make_empty, make_shared, make_from_string

feature -- Access

	encoding: INTEGER
		do
			Result := UTF_16_LE
		end

	partial_code_unit: INTEGER

feature -- Basic operations

	copy_as_utf_8 (dest: SPECIAL [CHARACTER]; dest_index, n: INTEGER)
		local
			dest_full, partial_pair, break: BOOLEAN; ptr: POINTER
			i, i_final, j, remaining_count, code_unit, partial_unit: INTEGER
		do
			partial_unit := partial_code_unit
			partial_code_unit := 0
			ptr := area; i_final := character_count - 1
			remaining_count := n

			i := 0; j := dest_index
			if pending_CR then
			-- The last chunked ended with a CR
				inspect eif_read_natural_16 (ptr, i).to_integer_32 when {ASCII}.NL then
					do_nothing
				else
				-- replace isolated '%R' with '%N'
					dest [j] := '%N'
					remaining_count := remaining_count - 1
					j := j + 1
				end
				pending_CR := False
			end
			from until i > i_final or dest_full or partial_pair loop
				inspect partial_unit when 0 then
				-- try and consume all ASCII characters
					from break := False until i > i_final or break or dest_full loop
						code_unit := eif_read_natural_16 (ptr, i)
						inspect code_unit when {ASCII}.CR then
							i := i + 1 -- skip '%R'
							if i > i_final then
							-- find out in next chunk if characters is Newline
								pending_CR := True
							else
								inspect eif_read_natural_16 (ptr, i).to_integer_32 when {ASCII}.NL then
									do_nothing
								else
								-- replace isolated '%R' with '%N'
									inspect remaining_count when 0 then
										dest_full := True
									else
										dest [j] := '%N'
										remaining_count := remaining_count - 1
										j := j + 1
									end
								end
							end
						else
							if code_unit < 0x80 then
								inspect remaining_count when 0 then
									dest_full := True
								else
									dest [j] := code_unit.to_character_8
									remaining_count := remaining_count - 1
									j := j + 1
									i := i + 1
								end
							else
								break := True
							end
						end
					end
				else
				end
				if i > i_final then
					do_nothing -- all remaining input consumed by ASCII fast path

				else
					inspect partial_unit when 0 then
						code_unit := eif_read_natural_16 (ptr, i)
					else
						code_unit := partial_unit -- residual unit from previous call to `copy_as_utf_8'
						i := i - 1
						partial_unit := 0
					end
					if code_unit < 0x80 then
					-- fast path stopped for lack of output space
						inspect remaining_count when 0 then
							dest_full := True
						else
							dest [j] := code_unit.to_character_8
							remaining_count := remaining_count - 1
							j := j + 1
							i := i + 1
						end
					elseif code_unit < 0x800 then
						inspect remaining_count when 0, 1 then
							dest_full := True
						else
							fill_2_bytes (dest, j, code_unit)
							remaining_count := remaining_count - 2
							j := j + 2
							i := i + 1
						end
					elseif code_unit >= 0xD800 and code_unit <= 0xDBFF then
					-- decode surrogate pair -> code point -> 4-byte UTF-8
						if i + 1 <= i_final then
							inspect remaining_count when 0, 1, 2, 3 then
								dest_full := True
							else
								fill_4_bytes (dest, j, code_unit, eif_read_natural_16 (ptr, i + 1))
								remaining_count := remaining_count - 4
								j := j + 4
								i := i + 2
							end
						else
						-- lone high surrogate at end of chunk: consume it here and
						-- carry it forward in `partial_code_unit' so that `last_index'
						-- and the residual unit are not counted twice
							partial_code_unit := code_unit
							i := i + 1
							partial_pair := True
						end
					else
						inspect remaining_count when 0, 1, 2 then
							dest_full := True
						else
							fill_3_bytes (dest, j, code_unit)
							remaining_count := remaining_count - 3
							j := j + 3
							i := i + 1
						end
					end
				end
			end
			utf_8_copied_count := n - remaining_count
			last_index := i * 2
			set_utf_8_to_count_ratio
		end

feature {NONE} -- Implementation

	fill_2_bytes (dest: SPECIAL [CHARACTER]; dest_index, code_unit: INTEGER)
		do
			dest [dest_index] := (0xC0 | (code_unit |>> 6)).to_character_8
			dest [dest_index + 1] := (0x80 | (code_unit & 0x3F)).to_character_8
		end

	fill_3_bytes (dest: SPECIAL [CHARACTER]; dest_index, code_unit: INTEGER)
		do
			dest [dest_index] := (0xE0 | (code_unit |>> 12)).to_character_8
			dest [dest_index + 1] := (0x80 | ((code_unit |>> 6) & 0x3F)).to_character_8
			dest [dest_index + 2] := (0x80 | (code_unit & 0x3F)).to_character_8
		end

	fill_4_bytes (dest: SPECIAL [CHARACTER]; dest_index, high_16, low_16: INTEGER)
		local
			code_unit: INTEGER
		do
			code_unit := 0x10000 + ((high_16 - 0xD800) |<< 10) + (low_16 - 0xDC00)
			dest [dest_index] := (0xF0 | (code_unit |>> 18)).to_character_8
			dest [dest_index + 1] := (0x80 | ((code_unit |>> 12) & 0x3F)).to_character_8
			dest [dest_index + 2] := (0x80 | ((code_unit |>> 6) & 0x3F)).to_character_8
			dest [dest_index + 3] := (0x80 | (code_unit & 0x3F)).to_character_8
		end

feature {NONE} -- Constants

	Code_unit_bytes: INTEGER = 2
end
