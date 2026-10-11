note
	description: "[
		${STRING_8} with attribute `is_open' for XML entity name to detect if an internal entity
		refers back to itself, either directly or through a chain.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-08-21 11:02:00 GMT (Friday 21th August 2026)"
	revision: "1"

class
	XT_ENTITY_NAME

inherit
	STRING_8

	XT_EXTERNAL_IDENTITY_I
		undefine
			copy, is_equal, out
		end

create
	make, make_empty, make_from_buffer, make_shared

feature {NONE} -- Initialization

	make_from_buffer (buffer: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; delimiter: CHARACTER)
		-- take buffer segment from `start_index' to `end_index' and insert into "&;" at position 2
		local
			l_count, full_count: INTEGER
		do
			l_count := end_index - start_index + 1
			full_count := l_count + 2
			make_filled ('%U', full_count)

			if attached area as a then
				a [0] := delimiter -- '&' OR '%'
				a.copy_data (buffer, start_index, 1, l_count)
				a [full_count - 1] := ';'
			end
			is_dtd_expandable := delimiter = '%%' or buffer [start_index] = '#'
		end

	make_shared (s: STRING)
		do
			area := s.area; count := s.count
			internal_hash_code := 0
			internal_case_insensitive_hash_code := 0
		end

feature -- Access

	external_id_type: INTEGER

	public_id: detachable STRING

	system_id: detachable STRING

feature -- Status query

	is_dtd_expandable: BOOLEAN
		-- `True' if entity should be expanded in literal values referenced in document type definition

	is_predefined: BOOLEAN
		local
			s: XT_STRING_8_ROUTINES
		do
			if attached area as l_area then
				Result := l_area [0] = '&' and then s.predefined_entity_code (l_area, 1, count - 2) > 0
			end
		end

	has_external_id: BOOLEAN
		-- `True' if the entity is defined externally to document
		do
			Result := external_id_type > 0
		end

	is_open: BOOLEAN

	is_unparsed: BOOLEAN
		-- `True' if entity was assigned with an NDATA type
		-- <!ENTITY img_gif SYSTEM "photo.gif" NDATA gif>
		-- It is not permissible to reference this entity anywhere if `True'

feature -- Element change

	set_external_id_type (a_external_id_type: INTEGER)
		do
			external_id_type := a_external_id_type
		end

	set_public_id (a_public_id: detachable STRING)
		do
			public_id := a_public_id
		end

	set_system_id (a_system_id: detachable STRING)
		do
			system_id := a_system_id
		end

feature -- Status change

	close
		do
			is_open := False
		end

	open
		do
			is_open := True
		end

	set_unparsed
		do
			is_unparsed := True
		end

end
