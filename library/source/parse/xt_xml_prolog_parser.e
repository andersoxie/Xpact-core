note
	description: "Parse prolog of XML document"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-08-16 13:40:00 GMT (Saturday 16th August 2026)"
	revision: "1"

deferred class
	XT_XML_PROLOG_PARSER

inherit
	XT_PARSING_BUFFERS
		export
			{XT_DOCUMENT_TYPE_PARTS_LIST} parser_data
		redefine
			make, set_defaults, reset
		end

	XT_DOCUMENT_SCANNER
		rename
			make as make_scanner
		end

	XT_PARSE_EVENTS
		export
			{XT_DOCUMENT_TYPE_PARTS_LIST} on_external_entity_reference
		end

	XT_PARSE_CONSTANTS

	XT_C_EXPANSION_ACCOUNTING_STRUCT

	XT_DTD_KEYWORDS

feature {NONE} -- Initialization

	make (a_parser_data: XT_PARSER_DATA)
		do
			Precursor (a_parser_data)

			create attribute_value_defaults_table.make (37)
			element_context := parser_data.new_element_context
			create parameter_entity_table.make (3)
			create parameter_name_cache.make

			make_scanner

			create attribute_parts_list.make (doctype_name_cache)
			create document_type_parts_list.make (doctype_name_cache)
			create element_parts_list.make (doctype_name_cache)
			create entity_parts_list.make (entity_cache)
			create notation_parts_list.make (doctype_name_cache)
			create parameter_entity_parts_list.make (parameter_name_cache)

			create declaration_parts.make_filled (document_type_parts_list, PARAMETER_ENTITY)
			declaration_parts [ATTLIST_ - 1] := attribute_parts_list
			declaration_parts [ELEMENT_ - 1] := element_parts_list
			declaration_parts [ENTITY_ - 1] := entity_parts_list
			declaration_parts [NOTATION_ - 1] := notation_parts_list
			declaration_parts [PARAMETER_ENTITY - 1] := parameter_entity_parts_list

		ensure then
			in_prolog_section: in_prolog_section
			content_count_is_one: parser_data.content_count = 1
		end

	set_defaults
		do
			Precursor
			declaration_count := 0; declaration_type := 0
			parser_data.set_defaults
			parser_data.set_exponential_expansion_threshold (Default_exponential_expansion_threshold)
		end

feature {NONE} -- Token processing

	process_doctype_definition (
		buf: like buffer; index, end_index, token: INTEGER; names: like name_cache
		parse_data: POINTER; done, default_case, common_case: TYPED_POINTER [BOOLEAN]
	): INTEGER
		local
			decl_type, declaration: INTEGER; parts_list: XT_DECLARATION_PARTS_LIST
		do
			inspect declaration_count when 0 then
				parts_list := document_type_parts_list
			else
				declaration := declaration_type
				parts_list := declaration_parts [declaration - 1]
			end
			inspect token
				when Tok_close_bracket then
					inspect declaration_count when 1 then
						set_in_dtd_section (parse_data, False)
					else
						Result := Error_syntax; put_boolean (done, True)
					end

				when Tok_decl_open then
					decl_type := to_declaration_type (buf, index + 2)
					inspect decl_type when 0 then
						Result := Error_syntax; put_boolean (done, True)
					else
						inspect declaration_count when 1 then
							push_declaration (decl_type)
						else
							Result := Error_syntax; put_boolean (done, True)
						end
					end

				when Tok_decl_close then
					inspect declaration_count when 2 then
						Result := on_close_declaration (declaration, token, parse_data)
						pop_declaration
					else
						Result := Error_syntax; put_boolean (done, True)
					end

				when Tok_name then
					inspect declaration when ATTLIST_ .. PARAMETER_ENTITY then
						inspect declaration_count when 2 then
							parts_list.extend (buf, index, end_index, token, newline_or_tab_found)
							if parts_list.is_complete then
								Result := on_close_declaration (declaration, token, parse_data)
							end
						else
							Result := Error_syntax; put_boolean (done, True)
						end
					else
						put_boolean (default_case, True)
					end

				when Tok_name_question, Tok_name_asterisk, Tok_name_plus then
					inspect declaration when ELEMENT_ then
						inspect declaration_count when 2 then
							parts_list.extend (buf, index, end_index - 1, token, newline_or_tab_found)
						else
							Result := Error_syntax; put_boolean (done, True)
						end
					else
						put_boolean (default_case, True)
					end

				when Tok_literal then
					inspect declaration when ATTLIST_ .. PARAMETER_ENTITY then
						inspect declaration_count when 2 then
							if attached expanded_dtd_literal (buf, index, end_index, parse_data) as str
								and then attached str.area as area
							then
								parts_list.extend (area, 0, str.count - 1, token, newline_or_tab_found)
								if parts_list.is_complete then
									Result := on_close_declaration (declaration, token, parse_data)
								end
							else
								parts_list.extend (buf, index + 1, end_index - 1, token, newline_or_tab_found)
								if parts_list.is_complete then
									Result := on_close_declaration (declaration, token, parse_data)
								end
							end
						else
							Result := Error_syntax; put_boolean (done, True)
						end
					else
						put_boolean (default_case, True)
					end

				when Tok_pound_name then
					inspect declaration when ATTLIST_ .. PARAMETER_ENTITY then
						parts_list.extend (buf, index, end_index, token, newline_or_tab_found)
						if parts_list.is_complete then
							Result := on_close_declaration (declaration, token, parse_data)
						end

					else
						put_boolean (default_case, True)
					end

				when Tok_percent then
					if declaration = ENTITY_ then
						if declaration_count = 2 then
							declaration := PARAMETER_ENTITY
							declaration_type := declaration
						end
					end

				when Tok_param_entity_ref then
					if c_param_entity_parsing_enabled (parse_data) then
						Result := process_parameter_entity (buf, index + 1, end_index - 1, names, parse_data, done)
					end

				when Tok_open_parenthesis, Tok_or, Tok_close_parenthesis, Tok_close_paren_plus,
					Tok_close_paren_question, Tok_close_paren_asterisk, Tok_comma
				then
					parts_list.on_operator (token)

			else
				put_boolean (common_case, True)
			end
		end

	process_parameter_entity (
		buf: like buffer; start_index, end_index: INTEGER; names: like name_cache; parse_data: POINTER
		done: TYPED_POINTER [BOOLEAN]
	): INTEGER
		local
			buffer_index_copy, error: INTEGER; entity_name: XT_ENTITY_NAME; source_type: NATURAL_8
			context: detachable STRING
		do
			entity_name := parameter_name_cache.item (buf, start_index, end_index)
			if entity_name.is_open then
				Result := Error_recursive_entity_ref; put_boolean (done, True)

			elseif attached parameter_entity_table.item (entity_name) as parameter then
				c_set_has_parameter_entity_reference (parse_data, True)
				if entity_name.has_external_id then
					if c_param_entity_parsing_enabled (parse_data) then
						if not on_external_entity_reference (entity_name, context, parse_data) then
							Result := Error_external_entity_handling
						end
					end
				else
					buffer_index_copy := buffer_index -- save field
					buffer_index := 0; source_type := c_accounting_source_type (parse_data)
					entity_name.open
					update_accounting_source_type (parse_data)
					error := process_content (parameter.area, 0, parameter.count, attribute_list, names, element_context, parse_data)  -- Recurse

					entity_name.close
					c_set_accounting_source_type (parse_data, source_type) -- restore accounting source type
					buffer_index := buffer_index_copy -- restore field
					set_in_cdata_section (parse_data, False) -- restore state

					inspect error when Error_none then
						do_nothing
					else
						put_boolean (done, True)
					end
					Result := error
				end
			else
				on_skipped_entity (entity_name, True, parse_data)
				Result := Error_undefined_entity; put_boolean (done, True)
			end
		end

	process_prolog (
		buf: like buffer; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST names: like name_cache
		parse_data: POINTER; a_index: TYPED_POINTER [INTEGER]; done: TYPED_POINTER [BOOLEAN]
	): INTEGER
		-- process XML prolog from `buf' writing back changes in values to `index' and `done'
		local
			token, tok_end, decl_type, index: INTEGER; default_case, common_case: BOOLEAN
		do
			index := read_integer_32 (a_index)
			token := scan_prolog (buf, index, end_index, parse_data)
			tok_end := next_token_index
			if c_in_dtd_section (parse_data) then
				Result := process_doctype_definition (
					buf, index, tok_end - 1, token, names, parse_data, done, $default_case, $common_case
				)
			else
				inspect token
					when Tok_xml_decl then
						if index > 0 then
							Result := Error_misplaced_xml_pi; put_boolean (done, True)
						end
						attributes.wipe_out

					when Tok_instance_start then
						if element_context.reached_depth_zero then
							Result := Error_junk_after_doc_element; put_boolean (done, True)
						else
							set_in_prolog_section (parse_data, False)
							attributes.set_undefined_entities_permitted (parser_data.undefined_entities_permitted)
							if not element_context.has_attributes and then attribute_value_defaults_table.count > 0 then
								create {XT_ELEMENT_ATTRIBUTES_CONTEXT} element_context.make (parse_data, attribute_value_defaults_table)
							end
						end

					when Tok_decl_open then
						decl_type := to_declaration_type (buf, index + 2)
						inspect decl_type when 0 then
							Result := Error_syntax; put_boolean (done, True)
						else
							if declaration_count = 0 and then decl_type = DOCTYPE_ then
								push_declaration (decl_type)
							else
								Result := Error_syntax; put_boolean (done, True)
							end
						end

					when Tok_decl_close then
						inspect declaration_count when 1 then
							pop_declaration
							if c_has_dtd_section (parse_data) then
								do_nothing
							else
								Result := on_close_declaration (DOCTYPE_, token, parse_data)
								if Result = 0 and then not c_is_standalone (parse_data) then
									Result := on_not_standalone (parse_data)
								end
								put_boolean (done, Result > 0)
							end
							if Result = 0 then
								Result := document_type_parts_list.on_document_type_end (Current)
							end
						else
							Result := Error_syntax; put_boolean (done, True)
						end

					when Tok_literal then
						inspect declaration_count when 1 then
							document_type_parts_list.extend (buf, index + 1, tok_end - 2, token, newline_or_tab_found)
						else
							Result := name_error (buf, index, end_index, parse_data); put_boolean (done, True)
						end

					when Tok_name then
						inspect declaration_count when 1 then
							document_type_parts_list.extend (buf, index, tok_end - 1, token, newline_or_tab_found)
						else
							Result := name_error (buf, index, end_index, parse_data); put_boolean (done, True)
						end

					when Tok_open_bracket then
						inspect declaration_count when 1 then
							set_in_dtd_section (parse_data, True)
							set_has_dtd_section (parse_data, True)
							Result := on_close_declaration (DOCTYPE_, token, parse_data)
							put_boolean (done, Result > 0)
						else
							Result := Error_syntax; put_boolean (done, True)
						end

				else
					common_case := True
				end
			end
			if common_case then
				inspect token
					when Tok_comment then
						on_comment (buf, index + 4, tok_end - 4, parse_data)

					when Tok_invalid then
						Result := Error_invalid_token
					-- Checking for binary data masquerading as XML
						if start_index = 0 and then not is_plausible_xml (buf, start_index, end_index, parse_data)
							and then has_syntax_error (buf, start_index, end_index, parse_data)
						then
							Result := Error_syntax
						end
						put_boolean (done, True)

					when Tok_open_bracket, Tok_close_bracket,
						tok_open_parenthesis, tok_close_parenthesis, Tok_or, Tok_name_question then
						if declaration_count = 0 then
							Result := Error_syntax; put_boolean (done, True)
						end

					when Tok_pi then
						on_processing_instruction (buf, index + 2, tok_end - 3, attributes, parse_data)
						attributes.wipe_out

					when Tok_prolog_whitespace then
						do_nothing

				else
					default_case := True
				end
			end
			if default_case then
				if element_context.reached_depth_zero and then not is_white_space (buf, index, end_index - 1) then
					Result := Error_junk_after_doc_element; put_boolean (done, True)

				elseif token <= 0 then
					put_boolean (done, True)  -- partial; wait for more data

				else
				-- skip prolog token					
					put_integer_32 (a_index, tok_end)
				end
			end
			if not read_boolean (done) then
				put_integer_32 (a_index, tok_end)
			end
		end

feature {NONE} -- Event handlers

	on_close_declaration (declaration, token: INTEGER; parse_data: POINTER): INTEGER
		do
			inspect declaration
				when ATTLIST_ then
					if attached attribute_parts_list as parts then
						inspect token when Tok_decl_close then
							if parts.is_valid_as_one then
								do_nothing -- legal syntax but does not call handler
							else
								inspect parts.count when 4, 5 then
									do_nothing -- already handled when `token /= Tok_decl_close'
								else
									Result := Error_syntax
								end
							end
							parts.wipe_out

						else
							if parts.is_complete then
								if attached parts.default_value as value then
									extend_attribute_value_defaults_table (parts, value)
								end
								on_attribute_list_declaration (parts, parse_data)
								parts.reset -- reset to just `element_name'
							else
								Result := Error_syntax
							end
						end
					end

				when ELEMENT_ then
					if attached element_parts_list as parts and then parts.is_valid then
						parts.on_close
						if attached parts.particle as model then
							on_element_declaration (parts.name, model, parse_data)
							parts.wipe_out
						else
							Result := Error_syntax
						end
					end

				when ENTITY_ then
					if attached entity_parts_list as parts then
						if parts.is_valid then
							parts.extend_table (entity_table)
							set_entity_handled (parse_data, False)
							on_entity (parts, parse_data)
							parts.wipe_out
						else
							Result := Error_syntax
						end
					end

				when DOCTYPE_ then
					if attached document_type_parts_list as parts then
						if parts.is_valid then
							on_doctype_declaration_start (parts, c_has_dtd_section (parse_data), parse_data)
							if parts.has_external_id then
								c_set_has_parameter_entity_reference (parse_data, True)
							end
						else
							Result := Error_syntax
						end
					end

				when NOTATION_ then
					if attached notation_parts_list as parts then
						if parts.is_valid then
							on_notation_declaration (parts, parse_data)
							parts.wipe_out
						else
							Result := Error_syntax
						end
					end

				when PARAMETER_ENTITY then
					if attached parameter_entity_parts_list as parts then
						if parts.is_valid then
							parts.extend_table (parameter_entity_table)
							on_entity (parts, parse_data)
							parts.wipe_out
						else
							Result := Error_syntax
						end
					end
			else
			end
		end

	on_entity (parts: XT_ENTITY_PARTS_I; parse_data: POINTER)
		require
			is_valid_list: parts.is_valid
		do
			if attached parts.entity_name as entity_name and then not entity_name.is_predefined then
				if entity_name.is_unparsed then
					on_unparsed_entity_declaration (parts, parse_data)
				end
				on_entity_declaration (parts, parse_data)
			end
		end

feature {NONE} -- Implementation

	extend_attribute_value_defaults_table (parts: XT_ATTRIBUTE_PARTS_LIST; value: STRING)
		local
			default_values_list: ARRAYED_LIST [STRING]
		do
			if attached attribute_value_defaults_table as table then
				if attached table [parts.element_name] as list then
					default_values_list := list
				else
					create default_values_list.make (5)
					table.extend (default_values_list, parts.element_name)
				end
				default_values_list.extend (parts.name)
				default_values_list.extend (value)
			end
		end

	in_prolog_section: BOOLEAN
		do
			Result := parser_data.in_prolog_section
		end

	expanded_dtd_literal (buf: like buffer; start_index, end_index: INTEGER; parse_data: POINTER): detachable STRING
		-- a string with expanded entities or `Void' if nothing expandable in document
		-- type definition
		require
			valid_start_character: Quote_marks.has (buf [start_index])
			valid_end_character: Quote_marks.has (buf [end_index])
		local
			index_buffer: SPECIAL [INTEGER]; entity_buffer: ARRAYED_LIST [XT_ENTITY_NAME]
			amp_index, i: INTEGER; found: BOOLEAN
		do
			amp_index := index_of (buf, '&', start_index, end_index)
			index_buffer := scanned_index_x4_buffer; entity_buffer := scanned_entity_buffer
			if amp_index > -1 then
				entity_buffer.wipe_out
				index_buffer.wipe_out
				inspect scan_attribute_value (buf, start_index, end_index + 1, buf.base_address, parse_data, index_buffer, entity_buffer)
					when 0 then
						if attached entity_buffer.area as area then
							from i := 0 until i = area.count or found loop
								if area [i].is_dtd_expandable then
									found := True
								else
									i := i + 1
								end
							end
							if found then
								Result := entity_table.expanded_value (buf, start_index + 1, end_index - 1, area, True, False)
							end
						end
				else end
				index_buffer.wipe_out
			end
		end

	name_error (buf: like buffer; start_index, end_index: INTEGER; parse_data: POINTER): INTEGER
		-- try and agree with eXpat on whether invalid XML will be regarded as a syntax error or invalid token
		-- the assumption is that element_context has been given some binary data masquerading as XML, for example:
		-- C:\Windows\WinSxS\amd64_microsoft-windows-deviceaccess_31bf3856ad364e35_10.0.26100.4202_none_a94ac2308a15fa4a\r\AppPrivacy.admx
		local
			token, index, tok_end, name_count: INTEGER; invalid_token: BOOLEAN
		do
			if element_context.reached_depth_zero then
				Result := Error_junk_after_doc_element

			elseif start_index = 0 then
				Result := Error_syntax
			else
				name_count := 1
			-- Find first section of invalid markup
				from index := start_index until index >= end_index or invalid_token or name_count >= 2 loop
					token := scan_prolog (buf, index, end_index, parse_data)
					inspect token
						when Tok_name then
							name_count := name_count + 1
						when Tok_invalid then
							invalid_token := True
					else
						tok_end := next_token_index
					end
					if not invalid_token then
						index := tok_end
					end
				end
				if name_count >= 2 then
					Result := Error_syntax

				elseif invalid_token then
					if has_syntax_error (buf, index, end_index, parse_data) then
						Result := Error_syntax
					else
						Result := Error_invalid_token
					end
				else
					if has_syntax_error (buf, tok_end, end_index, parse_data) then
						Result := Error_syntax
					else
						Result := Error_invalid_token
					end
				end
			end
		end

	new_test_encoding (name: STRING): detachable XT_CUSTOM_ENCODING_I
		-- test with one of two possible
		do
			if name ~ once "ISO-8859-15" then
			-- Test single-byte encodings
				create {XT_LATIN_15_ENCODING} Result.make

			elseif name ~ once "Shift_JIS_subset" then
			-- Test multi-byte encodings
			-- applies only to test file data/encoding-Shift_JIS_subset.xml
				create {XT_SHIFT_JIS_TEST_ENCODING} Result.make
			end
		end

	pop_declaration
		-- pop `declaration_type' from a virtual stack of max 2 items
		require
			depth_gt_zero: declaration_count > 0
		do
			declaration_count := declaration_count - 1
			inspect declaration_count when 1 then
				declaration_type := DOCTYPE_
			else
				declaration_type := 0
			end
		end

	push_declaration (type: INTEGER)
		-- push  `type' on to a virtual stack of max 2 items
		do
			declaration_count := declaration_count + 1
			declaration_type := type
		end

	read_declaration (chunk: XT_C_STRING_CODEC)
		-- read byte order mark and <?xml declaration (if they exist)
		-- and setting `encoding', `is_standalone' and `codec'
		require
			chunk_has_content: chunk.count > 0
		local
			declaration, yes_no: STRING; encoding_name: detachable STRING
			l_chunk: XT_UTF_8_CODEC; assumed_utf_8, utf_16_detected, is_utf_16: BOOLEAN
			lt_index, count: INTEGER
		do
			l_chunk := Default_codec
			l_chunk.make_shared (chunk.area, chunk.count)
			encoding := encoding_from_BOM (l_chunk)
			encoding_name := parser_data.protocol_encoding_name
		-- check for byte order mark if any and remove
			if encoding > 0 then
				l_chunk.remove_head (Encoding_byte_order_marks [encoding].count)
			end
			declaration := first_element (l_chunk, $lt_index)
			if declaration.is_empty then
				if l_chunk.is_whitespace then
					error_code := Error_no_elements
				end
			else
				utf_16_detected := prune_utf_16_nulls (declaration)
				inspect encoding when UTF_16, UTF_16_BE, UTF_16_LE then
					is_utf_16 := True
				else
					if utf_16_detected then
						encoding := UTF_16 -- detected in `utf_16_detected'
						is_utf_16 := True
					else
						encoding := UTF_8; assumed_utf_8 := True
					end
				end
				count := declaration.count -- <?xml ..?>
				if count >= 7 and then declaration [2] = '?'  and then declaration [count - 1] = '?'
					and then attached declaration.area as l_area
				then
					inspect scan_prolog (l_area, 0, declaration.count, parser_data.self_ptr) when Tok_xml_decl then
						if lt_index > 1 then
							error_code := Error_misplaced_xml_pi
						else
							yes_no := attribute_list.standalone_value (l_area)
							if Valid_yes_no.has (yes_no) then
								if yes_no [1] = 'y' then
									parser_data.set_standalone (True)
									if parser_data.parameter_entity_parsing = PE_parsing_unless_standalone then
										parser_data.set_parameter_entity_parsing (PE_parsing_never)
									end
								end
--								parser_data.set_dtd_keep_processing (is_standalone)
								on_xml_declaration (l_area, attribute_list, parser_data.self_ptr)
							-- ignore if `encoding_name' already set from `parser_data.protocol_encoding_name'
								if encoding_name = Void and then attached attribute_list.encoding_name (l_area) as name then
									encoding_name := name
								end
								attribute_list.wipe_out
							else
								error_code := Error_xml_decl
							end
						end
					else end
				end
				if error_code = Error_none then
					set_codec (l_chunk, encoding_name, assumed_utf_8, is_utf_16)
				end
			end
		end

	set_codec (chunk: XT_C_STRING_CODEC; encoding_name: detachable STRING; assumed_utf_8, is_utf_16: BOOLEAN)
		local
			custom_encoding: detachable XT_CUSTOM_ENCODING_I
			declared_encoding: INTEGER
		do
			if attached encoding_name as name then
				declared_encoding := Encoding_names_upper.index_of (name.as_upper, 1)
			end
			if valid_encoding (declared_encoding) and then valid_encoding (encoding)
				and then character_width (declared_encoding) /= character_width (encoding)
			then
				error_code := Error_incorrect_encoding

			elseif assumed_utf_8 and then valid_encoding (declared_encoding) then
				encoding := declared_encoding

			elseif attached encoding_name as name and then not (declared_encoding = UTF_16 and is_utf_16) then
				custom_encoding := on_unknown_encoding (name, parser_data.self_ptr)
				if attached custom_encoding as custom and then custom.is_valid then
					encoding := Unknown_encoding
				else
					error_code := Error_unknown_encoding
				end
			end
			inspect encoding
				when Ascii, Utf_8 then
					codec := Default_codec

				when Utf_16, UTF_16_LE then
					create {XT_UTF_16_LE_CODEC} codec.make_shared (chunk.area, chunk.count)

				when Latin_1 then
					create {XT_LATIN_1_CODEC} codec.make_shared (chunk.area, chunk.count)

				when Unknown_encoding then
					if attached custom_encoding as custom then
						create {XT_CUSTOM_CODEC} codec.make (chunk, custom)
					end
			else
			end
		end

	reset
		local
			i: INTEGER
		do
			Precursor {XT_PARSING_BUFFERS}

			attribute_value_defaults_table.wipe_out
			if element_context.has_default_values then
				create element_context.make (parser_data.self_ptr)
			else
				element_context.reset
			end
			parameter_name_cache.reset
			from i := 0 until i = declaration_parts.count loop
				declaration_parts [i].wipe_out
				i := i + 1
			end
			parameter_entity_table.wipe_out
		end

	to_declaration_type (buf: like buffer; offset: INTEGER): INTEGER
		-- one of: Attlist, Doctype, Element, Entity or 0 if no match
		local
			i: INTEGER
		do
			if attached Document_declarators as declarators then
				from i := 1 until i > declarators.count or Result > 0 loop
					if attached declarators [i] as name
						and then same_characters (buf, offset, offset + name.count - 1, name)
					then
						Result := i
					else
						i := i + 1
					end
				end
			end
		end

feature {NONE} -- Deferred

	process_content (
		buf: like buffer; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST; names: like name_cache
		a_context: XT_ELEMENT_CONTEXT; parse_data: POINTER
	): INTEGER
		require
			valid_range: start_index >= 0 and then start_index <= end_index
			end_in_buffer: buf = buffer implies end_index <= buffer_end
			buffer_index_at_start: buffer_index = start_index
		deferred
		ensure
			buffer_index_advanced: buffer_index >= start_index and buffer_index <= end_index
		end

feature {NONE} -- Declaration parts

	attribute_parts_list: XT_ATTRIBUTE_PARTS_LIST
		-- For example <!ATTLIST magic priority CDATA "50">

	declaration_parts: SPECIAL [XT_DECLARATION_PARTS_LIST]

	document_type_parts_list: XT_DOCUMENT_TYPE_PARTS_LIST

	element_parts_list: XT_ELEMENT_PARTS_LIST

	entity_parts_list: XT_ENTITY_PARTS_LIST

	notation_parts_list: XT_NOTATION_PARTS_LIST

	parameter_entity_parts_list: XT_PARAMETER_ENTITY_PARTS_LIST

feature {NONE} -- Tables

	attribute_value_defaults_table: HASH_TABLE [ARRAYED_LIST [STRING], STRING]

	parameter_entity_table: HASH_TABLE [STRING, XT_ENTITY_NAME]

feature {NONE} -- Internal attributes

	declaration_count: INTEGER
		-- current declaration depth
		-- <!DOCTYPE ..> is 1
		-- 	<!ENTITY ..> etc is 2

	declaration_type: INTEGER
		-- current declaration type being parsed. DOCTYPE is 1
		-- conceptually the top of a virtual stack of max 2 items

	element_context: XT_ELEMENT_CONTEXT

	parameter_name_cache: XT_PARAMETER_ENTITY_NAME_CACHE
		-- efficient lookup of parameter entity names

end
