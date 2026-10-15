note
	description: "XML Parsing buffers"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:30:45 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class
	XT_PARSING_BUFFERS

inherit
	XT_C_PARSER_STRUCT

	XT_BUFFER_CONSTANTS; XT_PARSE_ERROR_CONSTANTS; XT_ENCODING_TYPE_CONSTANTS

	XT_NAMING_MODE_CONSTANTS; XT_TOKEN_CONSTANTS; XT_STRING_CONSTANTS

feature {NONE} -- Initialization

	make (a_parser_data: XT_PARSER_DATA)
		require
			valid_parse_data_size: a_parser_data.count = c_size_of_parser_struct
		do
			parser_data := a_parser_data
			check attached Token_names end

			attribute_list := new_attribute_list
			entity_table := attribute_list.entity_table
			inspect a_parser_data.naming_mode when NM_prefix_SEP_localname then
				doctype_name_cache := name_cache
			else
				create doctype_name_cache.make
			end

			buffer := new_buffer_area (Default_buffer_size)
			create new_line.make_filled ('%N', 1)
			set_defaults
		ensure then
			empty_buffer: buffer_end = 0 and buffer_index = 0
		end

	set_defaults
		do
			codec := Default_codec
			encoding := UTF_8
			parse_end_index := 0
			position_index := 0
			buffer_end := 0
			buffer_index := 0
			error_code := Error_none
			inspect buffer_limit when 0 then
				buffer_limit := Default_buffer_size
			else
				buffer_limit := buffer.capacity - 1
			end
		end

feature -- Access

	buffer_limit: INTEGER
		-- Total usable capacity of `buffer'.

	encoding: INTEGER
		-- actual encoding or encoding assumption which may or may not be what is declared
		-- in <?xml ..

	error_code: INTEGER
		-- Most recent error (Error_none if none).

	error_description: STRING
		do
			if attached Error_descriptions.split ('%N') as list and then list.valid_index (error_code) then
				Result := list [error_code]
			else
				create Result.make_empty
			end
		end

feature -- Element change

	reset
		do
			set_defaults
			if codec.encoding /= UTF_8 then
				create {XT_UTF_8_CODEC} codec.make_empty
			end
			attribute_list.set_undefined_entities_permitted (False)
			attribute_list.reset -- also resets `name_cache' and `entity_table'
			if name_cache /= doctype_name_cache then
				doctype_name_cache.reset
			end
		end

feature {NONE} -- Factory

	new_attribute_list: XT_ATTRIBUTE_LIST
		do
			inspect parser_data.naming_mode when NM_prefix_SEP_localname then
				create Result.make (Default_attributes_capacity)
			else
				create {XT_URI_MAPPED_ATTRIBUTE_LIST} Result.make (Default_attributes_capacity, parser_data)
			end
		end

	new_buffer_area (n: INTEGER): like buffer
		do
			create Result.make_filled ('%U', n + 1)
		ensure
			room_for_null_terminator: Result.count = n + 1
		end

feature {NONE} -- Implementation

	character_width (a_encoding: INTEGER): INTEGER
		do
			inspect a_encoding when UTF_16, UTF_16_BE, UTF_16_LE then
				Result := 2
			else
				Result := 1
			end
		end

	encoding_from_BOM (chunk: XT_UTF_8_CODEC): INTEGER
		-- encoding from `chunk' byte order mark
		local
			i: INTEGER
		do
			from i := UTF_8 until i > UTF_16_LE or Result > 0 loop
				if chunk.starts_with_string (Encoding_byte_order_marks [i], 0) then
					Result := i
				else
					i := i + 1
				end
			end
		end

	first_element (chunk: XT_UTF_8_CODEC; lt_index_ptr: TYPED_POINTER [INTEGER]): STRING
		local
			lt_index, gt_index: INTEGER; s: XT_STRING_8_ROUTINES
		do
			Result := s.Empty_string
			lt_index := chunk.index_of ('<', 1)
			if lt_index > 0 then
				gt_index := chunk.index_of ('>', lt_index + 1)
				if gt_index > 0 then
					create Result.make (gt_index - lt_index + 1)
					chunk.append_slice_to_string_8 (Result, lt_index - 1, gt_index - 1)
				end
			end
		end

	name_cache: XT_NAME_CACHE
		-- efficient lookup of tag names
		do
			Result := attribute_list.name_cache
		end

	set_error_code (a_error_code: INTEGER)
		do
			error_code := a_error_code
		end

	prepare_buffer (a_count: INTEGER): BOOLEAN
			-- Ensure `buffer' has room for `a_count' more bytes
			-- after `buffer_end'.  Compacts or reallocates as needed,
			-- preserving up to `Context_bytes' before `buffer_index' for
			-- error reporting.  Returns False and sets `error_code' on
			-- failure; buffer indices are adjusted consistently on success.
			--
			-- Corresponds to the resize/compact logic in XML_GetBuffer().
		local
			needed, parsed, keep, offset, new_size: INTEGER
		do
			if a_count <= buffer_limit - buffer_end then
				-- Enough free space after buffer_end already.
				Result := True
			else
				parsed := buffer_index                 -- bytes before buffer_ptr
				keep   := parsed.min (Context_bytes)   -- context bytes to retain
				needed := keep + a_count + (buffer_end - buffer_index)

				if needed < 0 then
					-- Integer overflow: the request is impossibly large.
					error_code := Error_no_memory

				elseif needed <= buffer_limit then
					-- Existing allocation fits once we compact.
					offset := parsed - keep
					if offset > 0 then
						shift_buffer_left (offset)
					end
					Result := True

				else
					-- Must grow. Double from current capacity until large enough.
					new_size := buffer_limit.max (Default_buffer_size)
					from until new_size >= needed or new_size <= 0 loop
						if new_size > {INTEGER}.max_value // 2 then
							new_size := -1   -- overflow sentinel
						else
							new_size := new_size * 2
						end
					end
					if new_size <= 0 then
						error_code := Error_no_memory
					elseif attached new_buffer_area (new_size) as new_buffer then
						new_buffer.copy_data (buffer, 0, 0, buffer_limit)
						buffer := new_buffer
						buffer_limit := new_size
						offset := parsed - keep
						if offset > 0 then
							shift_buffer_left (offset)
						end
						Result := True
					end
				end
			end
		ensure
			space_when_ok:       Result implies buffer_end + a_count <= buffer_limit
			error_when_not_ok:   not Result implies error_code /= Error_none
			ptr_within_end:      buffer_index <= buffer_end
			end_within_lim:      buffer_end <= buffer_limit
			ptr_non_negative:    buffer_index >= 0
		end

	shift_buffer_left (offset: INTEGER)
			-- Slide all live content left by `offset' bytes and adjust
			-- every index that points into `buffer'.
			-- Safe for a forward (left) copy because destination < source.
		require
			positive_offset: offset > 0
			offset_leq_ptr: offset <= buffer_index
		do
			attribute_list.shift_buffer_left (buffer, offset)

			buffer.copy_data (buffer, offset, 0, buffer_end - offset)
			buffer_end := buffer_end - offset
			buffer_index := buffer_index - offset
			position_index := (position_index - offset).max (0)
			parse_end_index := (parse_end_index - offset).max (0)
		ensure
			buffer_ptr_reduced:  buffer_index  = old buffer_index  - offset
			buffer_end_reduced:  buffer_end  = old buffer_end  - offset
			ptr_non_negative:    buffer_index >= 0
			end_non_negative:    buffer_end >= 0
		end

feature {NONE} -- Internal attributes

	buffer_end: INTEGER
		-- Index one past the last valid data byte in `buffer'

	buffer_index: INTEGER
		-- Index of the first unprocessed byte in `buffer'

	parse_end_index: INTEGER
		-- Snapshot of buffer_end taken at the top of each parse call.

	position_index: INTEGER
		-- Start index for the next line/column position update.

feature {NONE} -- Internal structures

	attribute_list: XT_ATTRIBUTE_LIST
		-- collected attribute name-value pair indices into `buffer'

	buffer: SPECIAL [CHARACTER_8]
		-- Raw byte buffer; do not modify indices outside this class.

	codec: XT_C_STRING_CODEC
		-- codec wrapper for current data chunk being parsed

	doctype_name_cache: XT_NAME_CACHE
		-- name cache for use in all DOCTYPE declarations
		-- Normally refers to `name_cache' unless xmlns declarations are resolved
		-- with URI mapping then created separately

	entity_table: XT_ENTITY_TABLE
		-- table of expanded entities defined in DOCTYPE by ENTITY

	new_line: SPECIAL [CHARACTER_8]

	parser_data: XT_PARSER_DATA
		-- allocated memory for C struct `XT_C_PARSE_DATA_STRUCT'

feature {NONE} -- Constants

	Default_codec: XT_UTF_8_CODEC
		once
			create Result.make_empty
		end

	Default_attributes_capacity: INTEGER = 11

	Memory: MEMORY
		once
			create Result
		end

invariant
	room_for_null_terminator: buffer.capacity = buffer_limit + 1
	buffer_indices_consistent:
		buffer_index >= 0 and then buffer_index <= buffer_end and then buffer_end <= buffer_limit

	name_cache_same_as_declarations_name_cache:
		parser_data.naming_mode = NM_prefix_SEP_localname implies name_cache = doctype_name_cache

	not_name_cache_same_as_declarations_name_cache:
		parser_data.naming_mode /= NM_prefix_SEP_localname implies name_cache /= doctype_name_cache

end
