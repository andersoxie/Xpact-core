note
	description: "Declaration that can be externally linked by PUBLIC or SYSTEM parameters"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-09-29 08:20:00 GMT (Thursday 29th September 2026)"
	revision: "1"

deferred class
	XT_EXTERNALLY_LINKABLE_DECLARATION

inherit
	XT_EXTERNAL_IDENTITY_I

	XT_PARSE_CONSTANTS
		
		

	XT_DTD_KEYWORDS

	XT_STRING_8_ROUTINES_I

feature {NONE} -- Initialization

	make
		do
			external_id_type := 0
			create external_id_list.make_empty (2)
		end

feature -- Status query

	has_external_id: BOOLEAN
		-- `True' if has public or system id
		do
			Result := external_id_type > 0
		end

	has_public_id: BOOLEAN
		do
			Result := external_id_type = ID_public
		end

	has_system_id: BOOLEAN
		do
			Result := external_id_type = ID_system
		end

feature -- Measurement

	external_id_part_count: INTEGER
		-- 1 for SYSTEM, 2 for PUBLIC
		do
			inspect external_id_type when 0 then
				Result := 0
			else
				Result := 1 + has_public_id.to_integer
			end
		end

feature -- Access

	external_id_type: INTEGER

	external_id_list: SPECIAL [STRING]

	public_id: detachable STRING
		do
			if has_public_id and then external_id_list.count > 0 then
				Result := external_id_list [0]
			end
		end

	system_id: detachable STRING
		do
			if attached external_id_list as id_list and then id_list.count > 0 then
				if has_public_id and then id_list.count = 2 then
					Result := id_list [1]

				elseif has_system_id then
					Result := id_list [0]
				end
			end
		end

feature {NONE} -- Change parsing state

	extend_external_id (buffer: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER)
		do
			if attached external_id_list as id_list and then id_list.count < 2 then
				id_list.extend (new_public_id (buffer, start_index, end_index))
				if id_list.count = external_id_part_count then
					set_state (State_extending)
				end
			else
				set_state (State_extending)
			end
		end

	try_set_external_id (name: STRING)
		do
			if Valid_external_id_names.has (name) then
				external_id_type := if name = PUBLIC then ID_public else ID_system end
				set_state (State_external_id)
			end
		end

feature {NONE} -- Implementation

	new_public_id (area: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER): STRING_8
		-- public id substring of `area' from `lower' to `upper'
		-- The XML 1.0 spec's note on public identifiers (following the ExternalID/PublicID production)
		-- says that once the surrounding quotes are stripped from a PubidLiteral, the resulting string
		-- must be normalized by:
		-- 	1. discarding leading white space,
		-- 	2. discarding trailing white space, and
		-- 	3. replacing every internal run of white space with a single space character.
		local
			count, leading_count, i, j,  lower, upper: INTEGER
			c: CHARACTER
		do
			count := end_index - start_index + 1
			inspect count when 0 then
				Result := Empty_string
			else
				leading_count := leading_white_space (area, start_index, end_index)
				if leading_count = count then
					Result := Empty_string
				else
					lower := start_index + leading_count
					upper := end_index - trailing_white_space (area, lower, end_index)
					count := upper - lower + 1
					create Result.make (count)
					if attached Result.area as l_area then
						from i := lower; j := 0 until i > upper loop
							c := area [i]
							if c.is_space then
								c := ' ' -- replace tabs etc with space
							end
							l_area [j] := c
							if c = ' ' and then j > 0 then
							-- if `i' th character is space and previous was too then don't increment `j'
								inspect l_area [j - 1] when ' '  then
									do_nothing
								else
									j := j + 1
								end
							else
								j := j + 1
							end
							i := i + 1
						end
						Result.set_count (j)
					end
				end
			end
		end

	wipe_out
		-- Remove all items.
		do
			external_id_list.wipe_out
			external_id_type := 0
		end

feature {NONE} -- Deferred

	set_state (a_state: INTEGER)
		deferred
		end

	state: INTEGER
		-- parsing state of either extending `bucket_area'
		-- or building a name choice expression like (gif|jpg|png)
		deferred
		end

invariant
	valid_external_id_type: external_id_type > 0 implies Valid_external_id_names.valid_index (external_id_type )

end
