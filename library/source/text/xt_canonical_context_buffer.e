note
	description: "[
		A ${STRING_8} buffer that canonicalizes the order of `context' arguments 
		(as supplied to `XML_ExternalEntityRefHandler'). Excluding the entity name at the end
		the arguments are sorted alphabetically by splitting on the '%F' separator.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-10-14 09:27:57 GMT (Wednesday 14th October 2026)"
	revision: "1"

class
	XT_CANONICAL_CONTEXT_BUFFER

inherit
	STRING_8
		redefine
			make
		end

	PART_COMPARATOR [INTEGER_64]
		undefine
			copy, is_equal, out
		end

create
	make

feature {NONE} -- Initialization

	make (a_length: INTEGER)
		do
			Precursor (a_length)
			create interval_list.make (4)
			create quick.make (Current)
		end

feature -- Element change

	set_sorted (context: STRING_8)
		-- Append `context' to Current and, for each of its '%F' separated
		-- fields, add to `interval_list' the field's [l_lower, l_upper] character
		-- interval -- relative to Current, after the append -- packed into
		-- one INTEGER_64 with `l_lower' in the most-significant 32 bits.
		local
			l_lower, l_upper, sep_index: INTEGER; done: BOOLEAN
			ir: EL_INTERVAL_ROUTINES; l_area: like area; last: INTEGER_64
		do
			grow (context.count)
			l_area := area
			share (context)
			if attached interval_list as list then
				from sep_index := 0 until done loop
					l_lower := sep_index + 1
					sep_index := index_of ('%F', sep_index + 1)
					if sep_index > 0 then
						l_upper := sep_index - 1
						list.extend (ir.compact (l_lower, l_upper))
					else
						done := True
					end
				end
				list.extend (ir.compact (l_lower, count))
				check
					valid_count: list.count = context.occurrences ('%F') + 1
				end
				if list.count > 0 then
					last := list.last
					list.finish
					list.remove -- exclude entity name from sort
					quick.sort (list)
					list.extend (last) -- sorted, so we add back the entity name
				end
				area := l_area
				wipe_out
				from list.start until list.after loop
					if list.index > 1 then
						append_character ('%F')
					end
					append_substring (context, ir.to_lower (list.item), ir.to_upper (list.item))
					list.forth
				end
				list.wipe_out
			end
		ensure
			same_size: count = context.count
			same_separator_count: occurrences ('%F') = context.occurrences ('%F')
			ends_with_entity_name: last_part (Current).same_string (last_part (context))
		end

feature {NONE} -- Implementation

	last_part (context: STRING_8): STRING_8
		local
			sep_index: INTEGER
		do
			sep_index := context.last_index_of ('%F', context.count)
			if sep_index > 0 then
				Result := context.substring (sep_index + 1, context.count)
			else
				Result := context
			end
		end

	less_than (left_interval, right_interval: INTEGER_64): BOOLEAN
		local
			left_count, left_lower, right_count, right_lower: INTEGER; ir: EL_INTERVAL_ROUTINES
		do
			left_count := ir.count (right_interval); right_count := ir.count (right_interval)
			left_lower := ir.to_lower (left_interval) - 1
			right_lower := ir.to_lower (right_interval) - 1
			if right_count = left_count then
				Result := str_strict_cmp (area, area, right_lower, left_lower, right_count) > 0
			else
				if left_count < right_count then
					Result := str_strict_cmp (area, area, right_lower, left_lower, left_count) >= 0
				else
					Result := str_strict_cmp (area, area, right_lower, left_lower, right_count) > 0
				end
			end
		end

feature {NONE} -- Internal attributes

	interval_list: ARRAYED_LIST [INTEGER_64]
		-- array of string intervals `lower |..| upper' compacted as
		-- `(lower.to_integer_64 |<< 32) | upper.to_integer_64'

	quick: QUICK_SORTER [INTEGER_64]

end
