note
	description: "Writes UTF-8 encoded characters into ${SPECIAL [CHARACTER]} array"

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

	not_well_formed: BOOLEAN
		do
		end

	pending_CR: BOOLEAN
		-- `True' if previous content ended with '%R'

feature -- Measurement

	capacity: INTEGER
		deferred
		end

	character_count: INTEGER
		do
			Result := count
		end

	count: INTEGER
		deferred
		end

	utf_8_copied_count: INTEGER

feature -- Element change

	remove_head (n: INTEGER)
		require
			n_less_than_or_equal: n <= count
		deferred
		end

	reset
		do
		end

feature -- Basic operations

	copy_as_utf_8 (dest: SPECIAL [CHARACTER]; dest_index, n: INTEGER)
		require
			big_enough: dest.valid_index (dest_index + n - 1)
		deferred
		end

end
