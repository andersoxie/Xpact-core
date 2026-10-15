note
	description: "Writes UTF-8 encoded characters into parse buffer array of type ${SPECIAL [CHARACTER]}"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-07-30 07:48:00 GMT (Thursday 30th July 2026)"
	revision: "1"

deferred class
	XT_C_STRING_CODEC

inherit
	XT_ENCODING_TYPE_CONSTANTS

feature -- Initialization

	make_shared (a_ptr: POINTER; n: INTEGER)
		require
			n_is_multiple_of_code_unit_size: n.integer_remainder (code_unit_bytes) = 0
		deferred
		end

feature -- Access

	area: POINTER
		deferred
		end

	code_unit_bytes: INTEGER
		-- number of bytes per code unit
		deferred
		end

	encoding: INTEGER
		deferred
		end

	last_index: INTEGER

feature -- Status query

	pending_CR: BOOLEAN
		-- `True' if previous content ended with '%R'

feature -- Measurement

	capacity: INTEGER
		deferred
		end

	count: INTEGER
		deferred
		end

	characters_copied_count: INTEGER
		-- character count of data copied into `dest' argument in last call to `copy_as_utf_8'

feature -- Measurement

	character_count: INTEGER
		do
			Result := count // code_unit_bytes
		end

	estimated_utf_8_count: INTEGER
		do
			if utf_8_to_count_ratio.is_nan then
				Result := character_count
			else
				Result := (count * utf_8_to_count_ratio).ceiling
			end
		end

	utf_8_copied_count: INTEGER
		-- byte count of data copied into `dest' argument in last call to `copy_as_utf_8'

	uncopied_count: INTEGER
		-- remaining uncopied data after last call to `copy_as_utf_8'
		do
			Result := count - last_index
		end

feature -- Element change

	remove_head (n: INTEGER)
		require
			n_less_than_or_equal: n <= count
		deferred
		end

	reset_utf_8_to_count_ratio
		do
			utf_8_to_count_ratio := utf_8_to_count_ratio.nan
		end

feature -- Basic operations

	copy_as_utf_8 (dest: SPECIAL [CHARACTER]; dest_index, n: INTEGER)
		require
			big_enough: dest.valid_index (dest_index + n - 1)
		deferred
		ensure
			valid_last_index: last_index + uncopied_count = count
			utf_8_to_count_ratio_set: not utf_8_to_count_ratio.is_nan
		end

	set_utf_8_to_count_ratio
		do
			if utf_8_to_count_ratio.is_nan then
				utf_8_to_count_ratio := utf_8_copied_count / last_index.max (1)
			end
		end

feature {NONE} -- Internal attributes

	utf_8_to_count_ratio: DOUBLE

end
