note
	description: "${XT_NAME_CACHE} that resolves name space identifiers to URI's"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-09-14 08:27:00 GMT (Monday 14th September 2026)"
	revision: "1"

class
	XT_URI_MAPPED_NAME_CACHE

inherit
	XT_NAME_CACHE
		redefine
			attribute_item, entity_context, make, name_area, name_count, new_name,
			on_pop, on_xmlns_declaration_end,
			reset, transfer, valid_tag_name_count, Default_bucket
		end

	XT_STRING_CONSTANTS; XT_NAMING_MODE_CONSTANTS; XT_PARSE_ERROR_CONSTANTS

create
	make

feature {NONE} -- Initialization

	make
		do
			Precursor
			create xmlns_scope.make (bucket_area, 11); put_xml_uri
			create string_pool.make (20)
			create element_uri_table.make (5)
			create xmlns_scope_stack.make (5)
			create xmlns_scope_table.make (3)

			separator := Default_separator; naming_mode := NM_uri_SEP_localname
		end

feature -- Access

	entity_context (a_entity: XT_ENTITY_NAME): STRING
		do
			Result := entity_context_buffer
			Result.wipe_out
			xmlns_scope.append_to (Result)
			if a_entity.count >= 3 then
				if Result.count > 0 then
					Result.append_character ('%F')
				end
				Result.append_substring (a_entity, 2, a_entity.count - 1)
			end
		end

	separator: CHARACTER

	naming_mode: INTEGER

	attribute_item (buffer: SPECIAL [CHARACTER]; start_index, end_index, colon_index: INTEGER): like default_name
		do
			Result := item (buffer, start_index, end_index, colon_index).as_attribute
		end

feature -- Basic operations

	reset
		do
			Precursor
			xmlns_scope.wipe_out; put_xml_uri
			xmlns_scope_stack.wipe_out
			xmlns_scope_table.wipe_out
			element_uri_table.wipe_out
			depth := 0
		end

	transfer (
		buffer: SPECIAL [CHARACTER_8]; additions: SPECIAL [INTEGER]; colon_index: INTEGER
		attributes: XT_ATTRIBUTE_LIST; entity_list: ARRAYED_LIST [XT_ENTITY_NAME]
	): INTEGER
		-- add single xmlns declaration from `buffer' intervals specifified in `additions' and expanding any
		-- entities.
		local
			start_index: INTEGER; expanded_uri, uri, name_key: STRING
		do
			start_index := local_part_index (additions [0], colon_index)
			if entity_list.count > 0 and then attached attributes.entity_table as entity_table then
				expanded_uri := entity_table.expanded_value (buffer, additions [2], additions [3], entity_list.area, False, False)
				if entity_table.undefined_entity_found and then not attributes.undefined_entities_permitted then
					Result := Error_undefined_entity; uri := Empty_string
				else
					uri := new_recyleable (expanded_uri.area, 0, expanded_uri.count - 1)
				end
			else
				uri := new_recyleable (buffer, additions [2], additions [3])
			end
			check
				uri_not_shared_buffer: uri /= Output_buffer
			end
			if uri /= Empty_string then
				inspect colon_index when 0 then
					name_key := Default_uri_key
				else
					name_key := new_recyleable (buffer, start_index, additions [1])
				end
				element_uri_table.put (uri, name_key)
			end
			additions.wipe_out; entity_list.wipe_out
		end

feature -- Element change

	put_uri (uri, name_key: STRING)
		-- add namespace URI (for testing purposes only)
		do
			xmlns_scope.put (uri, name_key)
		end

	set_separator (a_separator: CHARACTER)
		do
			separator := a_separator
		end

	set_naming_mode (a_naming_mode: INTEGER)
		do
			naming_mode := a_naming_mode
		end

	set_naming (parser_data: XT_PARSER_DATA)
		do
			set_naming_mode (parser_data.naming_mode)
			set_separator (parser_data.namespace_separator)
		end

feature -- Event handler

	on_pop (element_context: XT_ELEMENT_CONTEXT; handler: XT_PARSE_EVENTS; parse_data: POINTER)
		-- notification after `element_context.pop' was called
		local
			element_depth: INTEGER
		do
			element_depth := element_context.depth
			inspect element_depth when 0 then
				xmlns_scope.on_pop (handler, parse_data)
			else
				if element_depth + 1 = depth and then attached xmlns_scope_stack as stack
					and then stack.count > 0 and then attached stack.item as scope
				then
					xmlns_scope.on_pop (handler, parse_data)
					bucket_area := scope.cache_bucket_area
					xmlns_scope := scope
					depth := scope.depth
					stack.remove
				end
			end
		end

	on_xmlns_declaration_end (
		buffer: SPECIAL [CHARACTER_8]; tag_name_lower, tag_name_upper: INTEGER
		parser: XT_XML_PARSER_BASE; attributes: XT_ATTRIBUTE_LIST
	)
		-- notification after reading list of attributes containing xmlns declaration
		local
			scope: XT_NAMESPACE_SCOPE; nested_scope, recycle_strings, is_default_name: BOOLEAN
			scope_key: STRING; element_context: XT_ELEMENT_CONTEXT; prefix: STRING
		do
			element_context := parser.element_context
			inspect element_context.depth when 0 then
				scope := xmlns_scope
				scope.append (element_uri_table)
			else
				nested_scope := True
				scope_key := scope_table_key (buffer, tag_name_lower, tag_name_upper)
				if attached xmlns_scope_table [scope_key] as found_scope then
				-- reuse a scope that was already created in an identical previous element
					scope := found_scope
					recycle_strings := True
				else
					scope := xmlns_scope.twin -- take a copy of parent scope for shadowing
					scope.set_cache_bucket_area (create {like bucket_area}.make_filled (Default_bucket, Size))
					scope.append (element_uri_table)
					scope_key := scope_key.twin
					check
						not_shared_buffer: scope_key /= empty_buffer
					end
					xmlns_scope_table [scope_key] := scope -- save scope for possible reuse in later element
				end
			end
			if nested_scope then
				xmlns_scope_stack.put (xmlns_scope) -- save current scope
				depth := element_context.depth + 1 -- plus 1 because element not yet processed
				scope.set_depth (depth)
				xmlns_scope := scope
				bucket_area := scope.cache_bucket_area
			end
		-- update any forward references to declared xmlns in attribute list
			if attached element_uri_table as table then
				from table.start until table.after loop
					if attached table.key_for_iteration as name and then attached table.item_for_iteration as uri then
						is_default_name := name = Default_uri_key
						attributes.check_forward (name, uri)
						if depth = 0 and is_default_name then
							element_context.update_default_attribute_names (Current)
						end
						prefix := if is_default_name then Empty_string else name end
						parser.on_namespace_declaration_start (prefix, uri, parser.parser_data.self_ptr)
						if recycle_strings then
						-- recycle strings borrowed during `transfer'
							if not is_default_name then
								string_pool.return (name)
							end
							string_pool.return (uri)
						end
					end
					table.forth
				end
			end
			element_uri_table.wipe_out
		end

feature -- Contract support

	valid_tag_name_count (tag_name: like default_name; expected_count: INTEGER): BOOLEAN
		do
			Result := tag_name.name_count = expected_count
		end

feature {NONE} -- Factory

	new_name (buffer: SPECIAL [CHARACTER]; start_index, end_index, colon_index: INTEGER): like default_name
		-- take buffer segment from `start_index' to `end_index' and insert into "&;" at position 2
		local
			name: STRING
		do
			inspect colon_index when 0 then
				name := Default_uri_key
			else
				name := empty_buffer
				append_area (name, buffer, start_index, colon_index - 1)
			end
			if attached xmlns_scope [name] as uri then
				create Result.make_from_uri (buffer, start_index, end_index, colon_index, naming_mode, uri, separator)

			else
				create Result.make_from_buffer (buffer, start_index, end_index, naming_mode)
			end
		end

	new_recyleable (buffer: SPECIAL [CHARACTER_8]; start_index, end_index: INTEGER): STRING_8
		-- substring of `buffer' that can be recycled again without GC when no longer needed
		do
			Result := string_pool.borrow_item (end_index - start_index + 1)
			Result.wipe_out
			append_area (Result, buffer, start_index, end_index)
		end

feature {NONE} -- Implementation

	put_xml_uri
		-- put URI "http://www.w3.org/XML/1998/namespace" for reserved name "xml"
		-- Eg. <svg sodipodi:docname="steam_icon_500.svg" xml:space="preserve" .. />
		do
			put_uri ({XT_STRING_CONSTANTS}.Xml_namespace_uri, {XT_STRING_CONSTANTS}.Xml_lower)
		end

	local_part_index (start_index, colon_index: INTEGER): INTEGER
		do
			inspect colon_index when 0 then
				Result := start_index
			else
				Result := colon_index + 1
			end
		end

	name_area (name: like default_name): SPECIAL [CHARACTER]
		do
			Result := name.name_area
		end

	name_count (name: like default_name): INTEGER
		do
			Result := name.name_count
		end

	scope_table_key (buffer: SPECIAL [CHARACTER_8]; tag_name_lower, tag_name_upper: INTEGER): STRING
		-- unique key to search for an existing scope `XT_NAMESPACE_SCOPE' that can be reused
		-- For example, the declaration from ATOM feed: <div xmlns='http://www.w3.org/1999/xhtml'>
		-- yields this key: "div|<default>|http://www.w3.org/1999/xhtml"
		do
			Result := empty_buffer
			append_area (Result, buffer, tag_name_lower, tag_name_upper) -- tag/element name
			if attached element_uri_table as table then
				from table.start until table.after loop
					Result.extend ('|'); Result.append (table.key_for_iteration)
					Result.extend ('|'); Result.append (table.item_for_iteration)
					table.forth
				end
			end
		end

feature {NONE} -- Internal attributes

	depth: INTEGER
		-- element depth of current shadow scope

	element_uri_table: HASH_TABLE [STRING, STRING]
		-- small buffer table to store xmlns declarations for most recent element

	string_pool: XT_STRING_BUFFER_POOL
		-- recycleable strings

	xmlns_scope: XT_NAMESPACE_SCOPE
		-- current scope of last element to define a namespace

	xmlns_scope_table: HASH_TABLE [XT_NAMESPACE_SCOPE, STRING]
		-- reuseable scopes looked up by `scope_table_key'

	xmlns_scope_stack: ARRAYED_STACK [XT_NAMESPACE_SCOPE]
		-- scopes of parent elements

feature {NONE} -- Constants

	Default_bucket: SPECIAL [XT_URI_MAPPED_NAME]
		once ("PROCESS")
			create Result.make_filled (create {like default_name}.make_empty, 1)
		end

	Default_separator: CHARACTER = '|'

invariant
	depth_same_as_stack_top_depth:
		(xmlns_scope_stack.count > 0 implies xmlns_scope_stack.item.depth = depth) or else depth = 0
end
