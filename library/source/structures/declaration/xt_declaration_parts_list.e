note
	description: "[
		List of parts for an ELEMENT or ATTLIST declaration
		
		For example:
			<!ATTLIST magic priority CDATA "50">
			
		would be:
			
			<< "magic", "priority", "CDATA", "50" >>
	]"
	notes: "See end of class"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-08-23 17:50:00 GMT (Sunday 23rd August 2026)"
	revision: "1"

class
	XT_DECLARATION_PARTS_LIST

inherit
	ARRAYED_LIST [STRING]
		rename
			first as name,
			empty as empty_list,
			extend as extend_list,
			make as make_sized,
			index_of as index_of_item
		export
			{NONE} all
		redefine
			new_filled_list, wipe_out
		end

	XT_TOKEN_CONSTANTS
		export
			{ANY} Tok_close_parenthesis
		undefine
			copy, is_equal
		end

	XT_PARSE_CONSTANTS
		
		undefine
			copy, is_equal
		end

	XT_DTD_KEYWORDS
		undefine
			copy, is_equal
		end

	XT_STRING_8_ROUTINES_I
		undefine
			copy, is_equal
		end

create
	make

feature {NONE} -- Initialization

	make (a_name_cache: like name_cache)
		do
			make_sized (11)
			make_external_id
			name_cache := a_name_cache
			last_name := Empty_string
			state := State_extending
			create token_area.make_empty (area.capacity)
			create option_list.make (50)
		end

feature -- Access

	i_th_token (i: INTEGER): INTEGER
		require
			valid_index: valid_index (i)
		do
			Result := token_area [i - 1]
		end

feature -- Status query

	has_notation_data: BOOLEAN
		do
			Result := count >= 2 and then i_th (count - 1) = NDATA
		end

	i_th_reserved (i: INTEGER): BOOLEAN
		require
			valid_index: valid_index (i)
		do
			Result := Reserved_identifiers.index_of (area [i - 1], 0) > -1
		end

	is_complete: BOOLEAN
		-- `True' if list is completed and therefore ready for calling `on_close_declaration'
		-- (redefined in `XT_ATTRIBUTE_PARTS_LIST')
		do
			Result := False
		end

	is_valid: BOOLEAN
		do
			Result := count > 0
		end

feature -- Element change

	extend (buffer: SPECIAL [CHARACTER_8]; start_index, end_index, token: INTEGER; newline_or_tab_found: BOOLEAN)
		require
			valid_range: start_index <= end_index + 1
		local
			i: INTEGER; l_area: like area_v2; l_token_area: like token_area; l_name: STRING
		do
			i := count + 1
			l_area := area_v2; l_token_area := token_area
			if i > l_area.capacity then
				l_area := l_area.aliased_resized_area (i + additional_space)
				l_token_area := l_token_area.aliased_resized_area (i + additional_space)
				area_v2 := l_area; token_area := l_token_area
			end
			inspect token
				when Tok_name, Tok_pound_name, Tok_name_question, Tok_name_asterisk, Tok_name_plus then
					if attached name_constant (buffer, start_index, end_index, token) as constant then
						l_name := constant
						try_set_external_id (l_name)

					elseif count > 1 and l_area [count - 1] = NDATA then
						l_name := new_notation_name (buffer, start_index, end_index)
					else
						l_name := new_name (buffer, start_index, end_index)
					end
					inspect state
						when State_extending then
							l_area.extend (l_name); l_token_area.extend (token)

						when State_building then
						-- building an expression like (gif|jpg|png)
							last_name := l_name
							on_name (l_name, token)
					else end

				when Tok_literal then
					inspect state when State_external_id then
						extend_external_id (buffer, start_index, end_index)
					else
						l_area.extend (new_value (buffer, start_index, end_index, newline_or_tab_found))
						l_token_area.extend (token)
					end
			else
			end
		end

	wipe_out
		-- Remove all items.
		do
			Precursor
			wipe_out_external_id

			token_area.wipe_out
			option_list.wipe_out
			state := State_extending
			last_name := Empty_string
		end

feature -- Event handlers

	on_operator (token: INTEGER)
		-- change parsing state for '(', ')' or '|' operators
		require
			big_enough_capacity: token = Tok_close_parenthesis implies count < capacity
		local
			i: INTEGER
		do
			inspect token
				when Tok_open_parenthesis then
					state := State_building
					option_list.wipe_out
					if attached area as l_area and then l_area.count > 1
						and then l_area [l_area.count - 1] = NOTATION
					then
						option_list.append (NOTATION)
					end
					option_list.append_character ('(')

				when Tok_close_parenthesis then
					option_list.append (last_name)
					option_list.append_character (')')
					if attached area as l_area and then l_area.count < l_area.capacity then
						if option_list.starts_with (NOTATION) then
							i := l_area.count - 1
							l_area [i] := option_list; token_area [i] := Tok_or
						else
							l_area.extend (option_list)
							token_area.extend (Tok_or)
						end
					end
					state := State_extending

				when Tok_or then
					option_list.append (last_name)
					option_list.append_character ('|')

			else end
		ensure
			OR_token_inserted: token = Tok_close_parenthesis implies is_OR_token_appended (token)
			valid_complex_type: token = Tok_close_parenthesis implies valid_complex_type (token)
		end

	on_name (a_name: STRING; token: INTEGER)
		do
		end

feature {NONE} -- Contract support

	is_OR_token_appended (token: INTEGER): BOOLEAN
		do
			Result := token_area [count - 1] = Tok_or
		end

	valid_complex_type (token: INTEGER): BOOLEAN
		do
			if attached last as s then
				Result := s = option_list and then s.count > 1 and then s [s.count] = ')'
			end
		end

feature {NONE} -- Implementation

	name_constant (buffer: SPECIAL [CHARACTER_8]; start_index, end_index, token: INTEGER): detachable STRING
		local
			i, i_upper: INTEGER; name_array: SPECIAL [STRING]
			first_letter_ok: BOOLEAN
		do
			inspect token when Tok_pound_name then
				name_array := Hash_identifiers
				first_letter_ok := buffer [start_index] = '#'
			else
				name_array := Reserved_identifiers
				first_letter_ok := is_reserved_first_letter (buffer [start_index])
			end
			if first_letter_ok then
				from i := 0; i_upper := name_array.count - 1 until i > i_upper or Result /= Void loop
					if same_characters (buffer, start_index, end_index, name_array [i]) then
						Result := name_array [i]
					else
						i := i + 1
					end
				end
			end
		end

	is_reserved_first_letter (c: CHARACTER): BOOLEAN
		do
			inspect c when 'P', 'S' then
				Result := True
			else
			end
		end

	set_state (a_state: INTEGER)
		do
			state := a_state
		end

feature {NONE} -- External PUBLIC/SYSTEM linking

	make_external_id
		do
			-- Implemented in  `XT_EXTERNALLY_LINKED_DECLARATION'
		end

	wipe_out_external_id
		do
			-- Implemented in  `XT_EXTERNALLY_LINKED_DECLARATION'
		end

	try_set_external_id (a_name: STRING)
		do
			-- Implemented in  `XT_EXTERNALLY_LINKED_DECLARATION'
		end

	extend_external_id (buffer: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER)
		require
			in_external_id_state: state = State_external_id
		do
			-- Implemented in  `XT_EXTERNALLY_LINKED_DECLARATION'
		end

feature {NONE} -- Factory

	new_name (buffer: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER): like name_cache.item
		local
			colon_index: INTEGER
		do
			colon_index := index_of (buffer, ':', start_index, end_index)
			Result := name_cache.item (buffer, start_index, end_index, colon_index.max (0))
		end

	new_notation_name (buffer: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER): STRING_8
		do
			Result := new_substring (buffer, start_index, end_index)
		end

	new_value (
		buffer: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER; newline_or_tab_found: BOOLEAN
	): STRING_8
		do
			Result := new_attribute_value (buffer, start_index, end_index, newline_or_tab_found)
		end

	new_filled_list (n: INTEGER): like Current
		do
			create Result.make (create {like name_cache}.make)
		end

feature {NONE} -- Internal attributes

	state: INTEGER
		-- parsing state of either extending `bucket_area'
		-- or building a name choice expression like (gif|jpg|png)

	last_name: STRING

	option_list: STRING
		-- (a|b|c) or NOTATION(a|b|c)

	name_cache: XT_NAME_CACHE

	token_area: SPECIAL [INTEGER]

feature {NONE} -- Reserved identifiers

	Hash_identifiers: SPECIAL [STRING]
		once
			create Result.make_empty (0)
		end

	Reserved_identifiers: SPECIAL [STRING]
		-- for both <!DOCTYPE ...> and  <!NOTATION ...>
		once
			Result := (<< PUBLIC, SYSTEM >>).area
		ensure
			all_reserved_first_letter:
				across Result as identifier all is_reserved_first_letter (identifier [1]) end
		end

feature {NONE} -- Constants

	Hash_fixed: STRING = "#FIXED"

	Hash_implied: STRING = "#IMPLIED"

	Hash_required: STRING = "#REQUIRED"

	Hash_pcdata: STRING = "#PCDATA"

note
	notes: "[

		<!ATTLIST ...> in attlist2's types[] (line 747-749), plus NOTATION and the DefaultDecl keywords in attlist2/attlist8:

			CDATA, ID, IDREF, IDREFS, ENTITY, ENTITIES, NMTOKEN, NMTOKENS: the 8 TokenizedType/StringType keywords
			NOTATION  introduces NotationType
			#REQUIRED, #IMPLIED, #FIXED: DefaultDecl (pound-prefixed)

		<!ENTITY ...>

			SYSTEM, PUBLIC:  external-ID keywords (both general and parameter entity forms)
			NDATA: introduces the notation name on an unparsed general entity

		<!ELEMENT ...>  element1, element2:

			EMPTY, ANY: the two atomic content-spec keywords
			#PCDATA: pound-prefixed, opens a Mixed content spec (element2)

		<!NOTATION ...>  notation1:

			SYSTEM, PUBLIC: external/public ID keywords (same two words as ENTITY, independently matched here)

		<!DOCTYPE ...> doctype1:

			SYSTEM, PUBLIC: same pair again, independently matched a third time
	]"

end
