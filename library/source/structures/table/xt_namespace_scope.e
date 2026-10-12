note
	description: "[
		Table of xmlns mappings bound to a name cache defined by ${XT_URI_MAPPED_NAME_CACHE}.bucket_area
		
		Example:
			rdf:RDF -> http://www.w3.org/1999/02/22-rdf-syntax-ns#
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-09-23 08:08:00 GMT (Monday 23rd September 2026)"
	revision: "1"

class
	XT_NAMESPACE_SCOPE

inherit
	HASH_TABLE [STRING, STRING]
		rename
			make as make_sized
		redefine
			empty_duplicate
		end

	XT_STRING_CONSTANTS
		undefine
			copy, is_equal
		end

create
	make

feature -- Initialization

	make (a_cache_bucket_area: like cache_bucket_area; n: INTEGER)
		do
			make_sized (n)
			cache_bucket_area := a_cache_bucket_area
			appended_positions := Empty_positions
		end

feature -- Access

	depth: INTEGER
		-- element depth of scope

	cache_bucket_area: SPECIAL [SPECIAL [XT_URI_MAPPED_NAME]]
		-- name cache `bucket_area' from `XT_URI_MAPPED_NAME_CACHE'

feature -- Basic operations

	append_to (entity_context: STRING)
		do
			if attached item (Default_uri_key) as uri then
				entity_context.append_character ('=')
				entity_context.append (uri)
			end
			from start until after loop
				if key_for_iteration /= Default_uri_key then
					if entity_context.count > 0 then
						entity_context.append_character ('%F')
					end
					entity_context.append (key_for_iteration)
					entity_context.append_character ('=')
					entity_context.append (item_for_iteration)
				end
				forth
			end
		end

feature -- Event handler

	on_pop (handler: XT_PARSE_EVENTS; parse_data: POINTER)
		-- notification after `element_context.pop' was called
		local
			i, key_index: INTEGER; s: XT_STRING_8_ROUTINES; prefix: STRING
		do
			if attached appended_positions as area then
			-- going in reverse order in which xmlns declarations were made
				from i := area.count - 1 until i < 0 loop
					key_index := area [i]
					if attached keys as key_area and then key_area.valid_index (key_index)
						and then attached key_area [key_index] as uri_key
					then
						prefix := if uri_key = Default_uri_key then s.Empty_string else uri_key end
						handler.on_namespace_declaration_end (prefix, parse_data)
					end
					i := i - 1
				end
			end
		end

feature -- Element change

	append (uri_table: HASH_TABLE [STRING, STRING])
		-- add new entries from `uri_table' and overwrite (shadow) existing ones.
		do
			if attached uri_table as table then
				from table.start until table.after loop
					force (table.item_for_iteration, table.key_for_iteration)
					table.forth
				end
			-- record appended item positions for calling handler `on_namespace_declaration_end'
				create appended_positions.make_empty (uri_table.count)
				from table.start until table.after loop
					internal_search (table.key_for_iteration)
					appended_positions.extend (position)
					table.forth
				end
			end
		end

	set_depth (a_depth: INTEGER)
		do
			depth := a_depth
		end

	set_cache_bucket_area (a_cache_bucket_area: like cache_bucket_area)
		do
			cache_bucket_area := a_cache_bucket_area
		end

feature {NONE} -- Duplication

	empty_duplicate (n: INTEGER): like Current
		-- Create an empty copy of Current that can accommodate `n' items
		do
			create Result.make (create {like cache_bucket_area}.make_empty (0), n)
			if object_comparison then
				Result.compare_objects
			end
		end

feature {XT_NAMESPACE_SCOPE} -- Internal attributes

	appended_positions: SPECIAL [INTEGER]
		-- positions of new entries added by `append'

feature {NONE} -- Constants

	Empty_positions: SPECIAL [INTEGER]
		once
			create Result.make_empty (0)
		end

end
