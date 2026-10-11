note
	description: "${STRING_8} related routines"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-06-28 6:31:14 GMT (Sunday 28th June 2026)"
	revision: "1"

class
	XT_STRING_8_ROUTINES_I

inherit
	XT_SHARED_INDEX_STACK

	STRING_HANDLER

feature {NONE} -- Access

	frozen area_substring (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER; keep_ref: BOOLEAN): STRING_8
		-- `lower .. upper' substring of `area' placed in `output_area'
		do
			Result := empty_buffer
			append_area (Result, area, lower, upper)
			if keep_ref then
				Result := Result.twin
			end
		ensure
			null_terminated: Result.area [Result.count] = '%U'
			not_keeping_definition: not keep_ref implies Result = Output_buffer
		end

	frozen ascii_to_utf_16 (str: STRING): STRING
		local
			i: INTEGER
		do
			create Result.make_filled ('%U', str.count * 2)
			from i := 1 until i > str.count loop
				Result [(i - 1) * 2 + 1] := str [i]
				i := i + 1
			end
		ensure then
			valid_last: Result [Result.count - 1] = str [str.count]
		end

	frozen char_ref_number (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): INTEGER
		-- Parse &#N; or &#xH; starting at '&'
		-- Unicode code point of the character reference starting at start_index ('&').
		-- Returns -1 if the value is not a legal XML character.
		local
			index: INTEGER; is_hex: BOOLEAN; c: CHARACTER
		do
			index := start_index + 2  -- skip '&' and '#'
			if index < end_index and buf [index] = 'x' then
				is_hex := True; index := index + 1
			end
			from until index >= end_index or buf [index] = ';' loop
				c := buf [index]
				if is_hex then
					inspect c
						when '0'..'9' then
							Result := (Result |<< 4) | (c - 48).code
						when 'A'..'F' then
							Result := (Result |<< 4) | (c - 55).code
					else
					-- 'a'..'f'
						Result := (Result |<< 4) | (c - 87).code
					end
				else
					Result := Result * 10 + (c - 48).code
				end
				if Result >= 0x110000 then
					Result := -1; index := end_index
				else
					index := index + 1
				end
			end
		end

	frozen predefined_entity_code (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): INTEGER
		-- Code point for predefined entity
		-- (lt=0x3C, gt=0x3E, amp=0x26, quot=0x22, apos=0x27), or -1 if not a predefined entity.
		require
			valid_range: valid_range (buf, start_index, end_index)
		do
			Result := -1
			inspect end_index - start_index + 1
				when 2 then
					inspect buf [start_index]
						when 'g' then
							if same_characters (buf, start_index, end_index, Predefined_gt) then
								Result := {ASCII}.Greaterthan -- 0x3E
							end
						when 'l' then
							if same_characters (buf, start_index, end_index, Predefined_lt) then
								Result := {ASCII}.Lessthan -- 0x3C
							end
					else end
				when 3 then
					if same_characters (buf, start_index, end_index, Predefined_amp) then
						Result := {ASCII}.Ampersand -- 0x26
					end
				when 4 then
					inspect buf [start_index]
						when 'q' then
							if same_characters (buf, start_index, end_index, Predefined_quot) then
								Result := {ASCII}.Doublequote -- 0x22
							end
						when 'a' then
							if same_characters (buf, start_index, end_index, Predefined_apos) then
								Result := {ASCII}.Singlequote -- 0x27
							end
					else end
			else end
		end

	frozen prune_utf_16_nulls (a_str: STRING): BOOLEAN
		-- transform UTF-16 to ascii as for example:
		-- "<%U?%Ux%Um%Ul%U.." becomes "<?xml.."
		-- `True' if half of `a_str' characters are null
		local
			uc: UTF_CONVERTER
		do
			if a_str.occurrences ('%U') = a_str.count // 2 and then attached empty_buffer as str then
				str.append (a_str); str.extend ('%U')
				a_str.wipe_out
				uc.utf_16le_string_8_into_utf_8_string_8 (str, a_str)
				Result := True
			end
		end

	frozen empty_buffer: STRING
		do
			Result := Output_buffer
			Result.wipe_out
		end

	frozen substitute (template: STRING; insertions: READABLE_INDEXABLE [STRING]): STRING
		require
			enough_place_holders: template.occurrences ('%S') = insertions.upper -  insertions.lower + 1
		local
			index, last_index, offset: INTEGER; index_stack: like Shared_index_stack
		do
			Result := template.twin
			index_stack := Shared_index_stack

			last_index := template.last_index_of ('%S', template.count)
			from until index = last_index loop
				index := Result.index_of ('%S', index + 1)
				if index > 0 then
					index_stack.put (index)
				end
			end
			offset := insertions.lower - 1
			from until index_stack.is_empty loop
				Result.replace_substring (insertions [index_stack.count - offset], index_stack.item, index_stack.item)
				index_stack.remove
			end
		ensure
			empty_stack: Shared_index_stack.is_empty
		end

	frozen to_list (str: STRING; c: CHARACTER): LIST [STRING]
		local
			i: INTEGER; c_string: ANY
		do
			Result := str.split (c)
			from i := 1 until i > Result.count loop
				if attached Result [i] as item then
					item.left_adjust
					c_string := item.to_c -- Null terminate
				end
				i := i + 1
			end
		ensure
			null_terminated: across Result as s all s.area [s.count] = '%U' end
		end

	frozen unescaped (code: INTEGER): like Char_area
		do
			Result := Char_area
			Result [0] := code.to_character_8
		end

	frozen utf_8_encoded (cp: INTEGER): like Char_area
		-- Encode Unicode code point `cp' as UTF-8 into `area'.
		-- Returns the number of bytes written (1..4).
		do
			Result := Char_area
			Result.wipe_out

			if cp <= 0x7F then
				Result.extend (cp.to_character_8)
			elseif cp <= 0x7FF then
				Result.extend ((0xC0 | (cp |>> 6)).to_character_8)
				Result.extend ((0x80 | (cp & 0x3F)).to_character_8)
			elseif cp <= 0xFFFF then
				Result.extend ((0xE0 | (cp |>> 12)).to_character_8)
				Result.extend ((0x80 | ((cp |>> 6) & 0x3F)).to_character_8)
				Result.extend ((0x80 | (cp & 0x3F)).to_character_8)
			else
				Result.extend ((0xF0 | (cp |>> 18)).to_character_8)
				Result.extend ((0x80 | ((cp |>> 12) & 0x3F)).to_character_8)
				Result.extend ((0x80 | ((cp |>> 6) & 0x3F)).to_character_8)
				Result.extend ((0x80 | (cp & 0x3F)).to_character_8)
			end
		end

	frozen valid_char_ref (code: INTEGER): INTEGER
			-- Return code if it is a legal XML character, else -1.
		do
			if code < 0 then
				Result := -1
			elseif (code |>> 8) >= 0xD8 and (code |>> 8) <= 0xDF then
				Result := -1  -- UTF-16 surrogate range
			elseif code < 0x20 and code /= 0x09 and code /= 0x0A and code /= 0x0D then
				Result := -1  -- forbidden C0 control characters
			elseif code = 0xFFFE or code = 0xFFFF then
				Result := -1  -- non-characters
			elseif code > 0x10FFFF then
				Result := -1  -- beyond Unicode range
			else
				Result := code
			end
		end

feature {NONE} -- Factory

	frozen new_attribute_value (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER; has_newline_or_tab: BOOLEAN): STRING_8
		-- `lower .. upper' substring of `area' placed in `output_area'
		require
			valid_upper: area.valid_index (upper)
		do
			if has_newline_or_tab then
				Result := area_substring (area, lower, upper, True)
				normalize_whitespace (Result.area, 0, Result.count - 1)
			else
				Result := area_substring (area, lower, upper, True)
			end
		end

	frozen new_abnormal_string (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): XT_ABNORMAL_STRING
		-- `lower .. upper' substring of `area' placed in `output_area'
		require
			valid_upper: area.valid_index (upper)
		do
			create Result.make (upper - lower + 1)
			append_area (Result, area, lower, upper)
		end

	frozen new_substring (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): STRING_8
		-- `lower .. upper' substring of `area' placed in `output_area'
		do
			Result := area_substring (area, lower, upper, True)
		end

	frozen new_string_list (list: READABLE_INDEXABLE [ANY]): ARRAYED_LIST [STRING]
		local
			i, upper: INTEGER; u: UTF_CONVERTER; item: ANY
		do
			upper := list.upper
			create Result.make (upper - list.lower + 1)
			from i := list.lower until i > upper loop
				item := list [i]
				if attached {PATH} item as path then
					Result.extend (new_unix_escaped (path))

				elseif attached {STRING} item as str then
					if is_ascii_string (str) or else u.is_valid_utf_8_string_8 (str) then
						Result.extend (str)
					else
						Result.extend (u.utf_32_string_to_utf_8_string_8 (str))
					end
				else
					Result.extend (item.out)
				end
				i := i + 1
			end
		end

	frozen new_unicode_substring (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): STRING_32
		-- `lower .. upper' substring of `area' placed in `output_area'
		local
			u: UTF_CONVERTER
		do
			Result := u.utf_8_string_8_to_string_32 (area_substring (area, lower, upper, False))
		end

	new_unix_escaped (a_path: PATH): STRING
		-- path escaped for Unix bash shell
		local
			path: STRING; i, i_upper: INTEGER; requires_escaping: BOOLEAN; c: CHARACTER
		do
			path := a_path.utf_8_name
			Result := path
			if attached Reserved_path_chars as reserved and then attached path.area as area then
				from i := 0; i_upper := path.count - 1 until i > i_upper or requires_escaping loop
					c := area [i]
					if not c.is_alpha_numeric and then (c = ' ' or else reserved.has (c)) then
						requires_escaping := True
					else
						i := i + 1
					end
				end
				if requires_escaping then
					create Result.make ((path.count * 1.3).ceiling)
					from i := 0 until i > i_upper loop
						c := area [i]
						inspect c when ' ' then
							Result.extend ('\')
						else
							if reserved.has (c) then
								Result.extend ('\')
							end
						end
						Result.extend (c)
						i := i + 1
					end
				end
			end
		end

	frozen key_set_string (key_list: ITERABLE [STRING]; keep_ref: BOOLEAN): STRING
		-- << "a", "b" >> -> "{a, b}"
		do
			Result := Output_buffer
			Result.wipe_out
			Result.append_character ('{')
			across key_list as key loop
				if Result.count > 2 then
					Result.append_string (", ")
				end
				Result.append_string (key)
			end
			Result.append_character ('}')
			if keep_ref then
				Result := Result.twin
			end
		end

feature {NONE} -- Status report

	frozen is_ascii (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): BOOLEAN
		-- `True' if all characters in `area' from `lower' to `upper' are ASCII
		require
			valid_range: upper + 1 >= lower and then upper >= lower implies area.valid_index (lower) and area.valid_index (upper)
		local
			i: INTEGER
		do
			Result := True
			from i := lower until i > upper loop
				if area [i] < '%/128/' then
					i := i + 1
				else
					Result := False
					i := upper + 1 -- break
				end
			end
		end

	frozen is_ascii_string (s: STRING): BOOLEAN
		do
			Result := is_ascii (s.area, 0, s.count - 1)
		end

	frozen is_white_space (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): BOOLEAN
		-- count of leading whitespace in `area' from `lower' to `upper'
		require
			valid_range: upper + 1 >= lower and then upper >= lower implies area.valid_index (lower) and area.valid_index (upper)
		local
			i: INTEGER
		do
			Result := True
			from i := lower until i > upper loop
				if area [i].is_space then
					i := i + 1
				else
					Result := False
					i := upper + 1 -- break
				end
			end
		end

	frozen null_terminated (str: STRING): BOOLEAN
		do
			Result := str.area [str.count] = '%U'
		end


	frozen same_characters (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER; string: STRING): BOOLEAN
		-- `True' if characters in `area' from `lower' to `upper' match those in `string'
		local
			i, j: INTEGER
		do
			if upper - lower + 1 = string.count and then attached string.area as string_area then
				Result := True
				from i := lower until i > upper loop
					if area [i] = string_area [j] then
						i := i + 1
						j := j + 1
					else
						Result := False
						i := upper + 1 -- break
					end
				end
			end
		ensure
			definition: Result implies new_substring (area, lower, upper).same_string (string)
		end

	frozen starts_with (area: SPECIAL [CHARACTER_8]; start_index: INTEGER; latin_1: STRING): BOOLEAN
		-- `True' if characters in `area' from `start_index' match those in `latin_1'
		local
			i, j, i_final, byte_count: INTEGER
		do
			byte_count := latin_1.count
			if area.valid_index (start_index + byte_count - 1) and then attached latin_1.area as string_area then
				Result := True
				i_final := start_index + byte_count - 1
				from i := start_index until i > i_final loop
					if area [i] = string_area [j] then
						i := i + 1
						j := j + 1
					else
						Result := False
						i := i_final + 1 -- break
					end
				end
			end
		end

	frozen same_caseless_characters (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER; string: STRING): BOOLEAN
		-- `True' if characters in `area' from `lower' to `upper' match those in `string' regardless of case
		local
			i, j: INTEGER; c_i, c_j: CHARACTER
		do
			if upper - lower + 1 = string.count and then attached string.area as string_area then
				Result := True
				from i := lower until i > upper loop
					c_i := area [i]; c_j := string_area [j]
					if c_i = c_j or else c_i.as_lower =  c_j.as_lower then
						i := i + 1
						j := j + 1
					else
						Result := False
						i := upper + 1 -- break
					end
				end
			end
		ensure
			definition: Result implies new_substring (area, lower, upper).same_caseless_characters (string, 1, string.count, 1)
		end

	valid_range (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): BOOLEAN
		do
			if start_index <= end_index then
				Result := end_index <= buf.count
			end
		end

	valid_substring_intervals (a_area: SPECIAL [INTEGER]): BOOLEAN
		-- `True' if all alternating (lower then upper) substring bounds are valid
		local
			i, l_count: INTEGER
		do
			l_count := a_area.count
			if l_count.integer_remainder (2) = 0 then
				from Result := True until i = l_count or not Result loop
					if (a_area [i + 1] + 1) >= a_area [i] then
						i := i + 2
					else
						Result := False
					end
				end
			end
		end

feature {NONE} -- Measurement

	frozen index_of (area: SPECIAL [CHARACTER_8]; c: CHARACTER_8; start_index, end_index: INTEGER): INTEGER
		-- Position of first occurrence of `c' at or after `start_index';
		-- -1 if none.
		require
			valid_range: start_index <= end_index + 1
			valid_start_index: area.valid_index (start_index)
			valid_end_index: end_index >= start_index implies area.valid_index (end_index)
		local
			i: INTEGER
		do
			from i := start_index until i > end_index or else area [i] = c loop
				i := i + 1
			end
			if i > end_index then
				Result := -1
			else
				Result := i
			end
		end

	frozen leading_white_space (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): INTEGER
		-- count of leading whitespace in `area' from `lower' to `upper'
		require
			valid_range: upper + 1 >= lower and then upper >= lower implies area.valid_index (lower) and area.valid_index (upper)
		local
			i: INTEGER
		do
			from i := lower until i > upper loop
				if area [i].is_space then
					Result := Result + 1; i := i + 1
				else
					i := upper + 1 -- break
				end
			end
		end

	frozen trailing_white_space (area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER): INTEGER
		-- count of trailing whitespace in `area' from `lower' to `upper'
		require
			valid_range: upper + 1 >= lower and then upper >= lower implies area.valid_index (lower) and area.valid_index (upper)
		local
			i: INTEGER
		do
			from i := upper until i < lower loop
				if area [i].is_space then
					Result := Result + 1; i := i - 1
				else
					i := lower - 1 -- break
				end
			end
		end

	frozen match_count (area: SPECIAL [CHARACTER_8]; offset: INTEGER; string: STRING): INTEGER
		-- count of characters in `area' from `offset' matching those from start of `string'
		require
			inside_area: area.valid_index (offset + string.count - 1)
		local
			i, string_count: INTEGER; string_area: SPECIAL [CHARACTER_8]
		do
			string_area := string.area; string_count := string_area.count
			from i := 0; until i = string_count loop
				if area [offset + i] = string_area [i] then
					Result := Result + 1
					i := i + 1
				else
					i := string_count -- break
				end
			end
		end

feature {NONE} -- Basic operations

	frozen append_area (str: STRING_8; area: SPECIAL [CHARACTER_8]; lower, upper: INTEGER)
		-- append contents of `area' from `lower' to `upper' to `str'
		require
			valid_range: upper + 1 >= lower and then upper >= lower implies area.valid_index (lower) and area.valid_index (upper)
		local
			count, new_count: INTEGER
		do
			count := upper - lower + 1; new_count := str.count + count
			str.grow (new_count)
			str.area.copy_data (area, lower, str.count, count)
			str.area [new_count] := '%U'
			str.set_count (new_count)
		end

	frozen fill_tuple (tuple: TUPLE; comma_separated_list: STRING)
		require
			enough_strings: tuple.count <= comma_separated_list.occurrences (',') + 1
		do
			if attached to_list (comma_separated_list, ',') as list then
				from list.start until list.after or list.index > tuple.count loop
					if tuple.valid_type_for_index (list.item, list.index) then
						tuple.put_reference (list.item, list.index)
					end
					list.forth
				end
			end
		end

	frozen normalize_whitespace (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER)
		--  %T and %N are replaced with a space
		-- XML §3.3.3 attribute-value normalisation: replace %N %T with space
		require
			valid_range: start_index <= end_index + 1
			valid_end_index: buf.valid_index (end_index)
		local
			i: INTEGER
		do
			from i := start_index until i > end_index loop
				inspect buf [i]
					when '%T', '%N' then
						buf [i] := ' '
				else
				end
				i := i + 1
			end
		end

	frozen null_terminate (str: STRING)
		do
			str.area [str.count] := '%U'
		end

feature {NONE} -- Constants

	Char_area: SPECIAL [CHARACTER]
		-- scratch 4-byte buffer for resolved entity/char-ref characters
		once
			create Result.make_filled ('%U', 4)
		end

	Empty_string: STRING_8
		-- used to initialize string attributes
		once
			create Result.make_empty
		end

	Output_buffer: STRING_8
		-- used to accumulate text for output
		once
			create Result.make (20)
		end

	Tab_spaces: STRING_8
		-- used to accumulate text for output
		once
			create Result.make_filled (' ', 3)
		end

	Reserved_path_chars: STRING = "*?[]<>|&;`$()%"%'!~ %T%N-"

feature {NONE} -- Predefined entities

	Predefined_apos: STRING_8 = "apos"

	Predefined_amp: STRING_8 = "amp"

	Predefined_gt: STRING_8 = "gt"

	Predefined_lt: STRING_8 = "lt"

	Predefined_quot: STRING_8 = "quot"

invariant
	empty_definition: Empty_string.is_empty
end
