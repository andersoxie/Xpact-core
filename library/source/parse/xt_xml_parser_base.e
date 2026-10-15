note
	description: "Incremental XML parser based on eXpat port"
	notes: "See end of class"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:30:52 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class
	XT_XML_PARSER_BASE

inherit
	XT_XML_PROLOG_PARSER
		export
			{ANY} read_natural_64
			{XT_URI_MAPPED_NAME_CACHE, XT_TAG_SCANNER} element_context, on_namespace_declaration_start, parser_data
		redefine
			make, set_defaults
		end

	XT_NAMING_MODE_CONSTANTS

feature {NONE} -- Initialization

	make (a_parse_data: XT_PARSER_DATA)
		do
			Precursor (a_parse_data)
			if not (a_parse_data.max_expansion_proportion >= 1.0) then
				parser_data.set_max_expansion_proportion (Default_max_expansion_proportion)
			end
		ensure then
			set_to_check_encoding: parsing_state = State_check_encoding
			no_error: error_code = Error_none
			handler_clean: handler_call_depth = 0
		end

	set_defaults
		do
			Precursor
			parsing_state              := State_check_encoding
			status 							:= 0

			is_final_buffer            := False
			reparse_deferral_enabled   := True

			last_buffer_request_size   := 0
			partial_token_bytes_before := 0
			parse_end_byte_index       := 0
		end

feature -- Access

	handler_call_depth: NATURAL
		do
			Result := parser_data.handler_call_depth
		end

	parsing_state: INTEGER
			-- Current state: one of the State_* constants.

	status: INTEGER
		-- Current state after reading file: one of the Status_* constants.

	status_description: STRING
		do
			if attached Status_names.split ('%N') as list and then list.valid_index (status + 1) then
				Result := list [status + 1]
			else
				create Result.make_empty
			end
		end

feature -- Measurement

	parsed_content_count: NATURAL_64
		do
			Result := parser_data.content_count
		end

feature -- Status query

	is_final_buffer: BOOLEAN
		-- Was the current parse call marked as the last chunk?

feature -- Basic operations

	parse_file (file_path: PATH; chunk_size: INTEGER; collection_off: BOOLEAN)
		local
			file: XT_XML_FILE
		do
			create file.make (file_path, Current)
			if chunk_size > 0 then
				file.set_chunk_size (chunk_size)
			end
			if file.is_readable then
				file.open_read
				file.parse
				status := file.parse_status
			else
				error_code := Error_file_not_readable
				status := Status_error
			end
		end

	parse (chunk: XT_C_STRING_CODEC; a_is_final: BOOLEAN): INTEGER
		-- Accept `a_count' bytes from `chunk[a_offset]' as the next chunk.
		-- Returns Status_ok, Status_suspended, or Status_error.
		-- Corresponds to XML_Parse() in xmlparse.c.
		require
			content_count_at_least_1: parsed_content_count >= 1 -- guards against division by zero later
		local
			utf_8_copied_count, estimated_utf_8_count: INTEGER; parse_data: POINTER
			done: BOOLEAN
		do
			parse_data := parser_data.self_ptr
			inspect parsing_state
				when State_check_encoding then
					Memory.collection_off
					if chunk.count = 0 then
						error_code := Error_no_elements
					else
						read_declaration (chunk)
					end
					inspect error_code when Error_none then
						parsing_state := State_initialized
						Result := parse (codec, a_is_final) -- Recurse
					else
						status := Status_error
					end

				when State_suspended then
					error_code := Error_suspended
					Result := Status_error

				when State_finished then
					error_code := Error_finished
					Result := Status_error
			else
			-- State_initialized or State_parsing
				if codec /= chunk then
					codec.make_shared (chunk.area, chunk.count)
				end
				parsing_state := State_parsing
				if not call_on_start_parsing then
					Result := Status_error

				else
					codec.reset_utf_8_to_count_ratio
				-- Copy data from codec buffer as UTF-8 into parse buffer until emptied
					from utf_8_copied_count := 0; done := codec.count = 0 until Result > 0 or done loop
						estimated_utf_8_count := codec.estimated_utf_8_count
						if prepare_buffer (utf_8_copied_count + estimated_utf_8_count) then
							codec.copy_as_utf_8 (buffer, buffer_end + utf_8_copied_count, estimated_utf_8_count)
							utf_8_copied_count := utf_8_copied_count + codec.utf_8_copied_count
							if codec.uncopied_count = 0 or codec.utf_8_copied_count = 0 then
								done := True
							else
								codec.remove_head (codec.last_index)
							end
						else
							Result := Status_error
						end
					end
					if Result = 0 and then utf_8_copied_count > 0 then
						Result := parse_buffer (utf_8_copied_count, a_is_final, parse_data)
					end
				end
				if a_is_final then
					if error_code = Error_none and then not element_context.reached_depth_zero then
						error_code := Error_no_elements
						Result := Status_error
					end
					Memory.collection_on; Memory.full_collect
				end
			end
		ensure
			valid_result: Status_range.has (Result)
			finished_when_final_ok:
				(Result = Status_ok and a_is_final) implies parsing_state = State_finished
			error_code_set_on_error:
				Result = Status_error implies error_code /= Error_none
		end

	put_error (output: IO_MEDIUM; file_path: PATH)
		do
			if status = Status_error then
				inspect error_code
					when Error_file_not_readable then
						output.put_string ("Cannot read: " + file_path.utf_8_name)
				else
					output.put_string ("Parse error: "); output.put_string (error_description)
				end
				output.put_new_line
			end
		end

	put_status (output: IO_MEDIUM)
		do
		end

feature {NONE} -- Buffer implementation

	parse_buffer (a_count: INTEGER; a_is_final: BOOLEAN; parse_data: POINTER): INTEGER
		-- Parse `a_count' bytes that the caller has already written into
		-- `buffer' starting at the old `buffer_end'.
		-- Returns Status_ok, Status_suspended, or Status_error.
		-- Corresponds to XML_ParseBuffer() in xmlparse.c.
		require
			non_negative_count: a_count >= 0
			not_in_handler:     handler_call_depth = 0
			buffer_allocated:   buffer_limit > 0
			data_fits:          buffer_end + a_count <= buffer_limit
		local
			start: INTEGER
		do
			inspect parsing_state
				when State_check_encoding then

				when State_suspended then
					error_code := Error_suspended
					Result := Status_error

				when State_finished then
					error_code := Error_finished
					Result := Status_error
			else
				if not call_on_start_parsing then
					Result := Status_error
				else
					parsing_state        := State_parsing
					start                := buffer_index
					position_index       := start
					buffer_end           := buffer_end + a_count
					parse_end_index      := buffer_end
					parse_end_byte_index := parse_end_byte_index + a_count
					is_final_buffer      := a_is_final

					error_code := call_processor (start, parse_end_index, parse_data)

					inspect error_code when Error_none then
						inspect parsing_state
							when State_suspended then
								Result := Status_suspended
						else
							if a_is_final then
								parsing_state := State_finished
								on_finish (Status_ok)
							end
							Result := Status_ok
						end
						on_update_position (position_index, buffer_index)
						position_index := buffer_index

					when Error_misplaced_xml_pi then
						on_set_error_processor
						Result := Status_error

					else
						on_set_error_processor
						Result := Status_error
					end
				end
			end
		ensure
			valid_result: Status_range.has (Result)
			finished_when_final_ok:
				(Result = Status_ok and a_is_final) implies parsing_state = State_finished
			error_code_set_on_error:
				Result = Status_error implies error_code /= Error_none
			byte_index_advanced:
				Result /= Status_error implies
					parse_end_byte_index = old parse_end_byte_index + a_count
		end

	get_buffer (a_count: INTEGER): BOOLEAN
			-- Prepare the internal buffer to accept `a_count' more bytes.
			-- On success the caller may write directly into
			-- `buffer [buffer_end .. buffer_end + a_count)'.
			-- Returns False and sets `error_code' on failure.
			--
			-- Corresponds to XML_GetBuffer() in xmlparse.c.
		require
			non_negative_count: a_count >= 0
			not_in_handler:     handler_call_depth = 0
			not_suspended:      parsing_state /= State_suspended
			not_finished:       parsing_state /= State_finished
		do
			last_buffer_request_size := a_count
			Result := prepare_buffer (a_count)
		ensure
			space_when_ok:        Result implies buffer_end + a_count <= buffer_limit
			error_set_on_failure: not Result implies error_code /= Error_none
			request_size_saved:   last_buffer_request_size = a_count
		end

feature {NONE} -- Processor dispatch

	call_processor (start_index, end_index: INTEGER; parse_data: POINTER): INTEGER
			-- Drive the current processor over `buffer [start_index .. end_index]'.
			-- Implements the reparse-deferral heuristic and the re-enter loop
			-- from callProcessor() in xmlparse.c.
			-- Updates `buffer_index' to the furthest position reached.
			-- Returns Error_none on success or an Error_* code on failure.
		require
			valid_range:  start_index >= 0 and then start_index <= end_index
			end_in_buf:   end_index <= buffer_end
			ptr_at_start: buffer_index = start_index
		local
			error, have_now, had_before, available: INTEGER; enough, done: BOOLEAN; context: XT_ELEMENT_CONTEXT
			names: like name_cache; attributes: like attribute_list; buf: like buffer
		do
			have_now := end_index - start_index

			-- Reparse-deferral heuristic (m_reparseDeferralEnabled in xmlparse.c):
			-- avoid re-scanning a partial token until we have significantly more data
			-- or the buffer is nearly full.
			if reparse_deferral_enabled and then not is_final_buffer then
				had_before := partial_token_bytes_before
				available  := (buffer_index - buffer_index.min (Context_bytes)) + (buffer_limit - buffer_end)
				enough := have_now >= 2 * had_before
					or else last_buffer_request_size > available
				if not enough then
					-- Leave buffer_index at start_index; nothing consumed this call.
					Result := Error_none
				end
			else
				enough := True
			end
			if enough then
				-- Re-enter loop: drives the processor repeatedly when it sets
				-- the reenter flag (avoids deep C-style recursion).
				context := element_context; names := name_cache; attributes := attribute_list; buf := buffer

				from done := False until done loop
					error := process_content (buf, buffer_index, end_index, attributes, names, context, parse_data)

					-- Suspended state overrides the reenter request.
					inspect parsing_state when State_parsing then
						do_nothing
					else
						on_clear_reenter
					end

					if not processor_wants_reenter then
						done := True
					else
						on_clear_reenter
						inspect error when Error_none then
							do_nothing
						else
							Result := error
							done := True
						end
					end
				end
				Result := error
			end

			-- Track how many bytes were available but not consumed,
			-- so the deferral heuristic can judge the next call.
			inspect Result when Error_none then
				if buffer_index = start_index then
					partial_token_bytes_before := have_now
				else
					partial_token_bytes_before := 0
				end
			else
			end
		ensure
			buffer_index_in_range: buffer_index >= start_index and buffer_index <= end_index
			error_code_unchanged_on_success: Result = Error_none
				implies error_code = old error_code
		end

	call_on_start_parsing: BOOLEAN
		-- If currently in State_initialized, call `on_start_parsing' for a
		-- root parser; always succeeds for child/entity parsers.
		-- Returns False only when `on_start_parsing' fails.
		do
			if parsing_state = State_initialized then
				if not on_start_parsing then
					error_code := Error_no_memory
				else
					Result := True
				end
			else
				Result := True
			end
		ensure
			error_set_on_failure: not Result implies error_code /= Error_none
		end

	process_content (
		buf: like buffer; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST
		names: like name_cache; a_context: XT_ELEMENT_CONTEXT; parse_data: POINTER
	): INTEGER
		-- Scan tokens from `buf' `start_index .. end_index` and triggers relevant XML events.  Advances `buffer_index'.
		-- Execute one pass of the current processor over `buf [start_index .. end_index)'.
		-- Must update `buffer_index' to the first unconsumed byte.
		-- Returns Error_none on success or an Error_* code on failure.
		-- Corresponds to a single call of `m_processor' in xmlparse.c.
		local
			code, index, token, tok_end: INTEGER; context: XT_ELEMENT_CONTEXT; tag_name: STRING; done: BOOLEAN
		do
			index := start_index; context := a_context
			from until index >= end_index or done loop
				if c_in_prolog_section (parse_data) then
					Result := process_prolog (buf, start_index, end_index, attributes, names, parse_data, $index, $done)
					context := element_context

				elseif c_in_cdata_section (parse_data) then
					token := scan_cdata_section (buf, index, end_index, parse_data)
					tok_end := next_token_index
					inspect token
						when Tok_cdata_sect_close then
							on_cdata_section_end (parse_data)
							set_in_cdata_section (parse_data, False)
							index := tok_end

						when Tok_data_chars then
							on_content (buf, index, tok_end - 1, parse_data)
							index := tok_end

						when Tok_data_newline then
							on_content (new_line, 0, 0, parse_data)
							index := tok_end

					else
						if token = Tok_invalid then
							Result := Error_invalid_token; done := True
						else
							done := True  -- partial; wait for more data
						end
					end
				else
					token := scan_content (buf, index, end_index, parse_data)
					tok_end := next_token_index
					inspect token
						when Tok_cdata_sect_open then
							set_in_cdata_section (parse_data, True)
							on_cdata_section_start (parse_data)

						when Tok_invalid then
							Result := Error_invalid_token; done := True

						when Tok_data_chars then
							on_content (buf, index, tok_end - 1, parse_data)

						when Tok_data_newline then
							on_content (new_line, 0, 0, parse_data)

						when Tok_start_tag_no_attributes then
							context.push (cached_tag_name (buf, index, names))
							on_element_start (buf, context, attributes, token, parse_data)

						when Tok_start_tag_with_attributes then
							context.push (cached_tag_name (buf, index, names))
							on_element_start (buf, context, attributes, token, parse_data)
							attributes.wipe_out

						when Tok_empty_element_with_attributes, Tok_empty_element_no_attributes then
							tag_name := cached_tag_name (buf, index, names)
							context.push (tag_name)
							on_element_start (buf, context, attributes, token, parse_data)
							inspect token when Tok_empty_element_with_attributes then
								attributes.wipe_out
							else
							end
							on_element_end (tag_name, parse_data)
							inspect context.pop (tag_name) when Error_tag_mismatch then
								Result := Error_tag_mismatch; done := True
							else
								names.on_pop (context, Current, parse_data)
							end

						when Tok_end_tag then
							tag_name := cached_tag_name (buf, index + 1, names)
							on_element_end (tag_name, parse_data)  -- skip '</'
							inspect context.pop (tag_name) when Error_tag_mismatch then
								Result := Error_tag_mismatch; done := True
							else
								names.on_pop (context, Current, parse_data)
							end

						when Tok_comment then
							on_comment (buf, index + 4, tok_end - 4, parse_data)

						when Tok_pi then
							on_processing_instruction (buf, index + 2, tok_end - 3, attributes, parse_data)
							attributes.wipe_out

						when Tok_entity_ref then
							Result := process_entity (buf, index + 1, tok_end - 2, attributes, names, context, parse_data, $done)

						when Tok_char_ref then
							-- index is '&'; tok_end is exclusive end past ';'
							code := char_ref_number (buf, index, tok_end)
							inspect valid_char_ref (code) when -1 then
								Result := Error_bad_char_ref; done := True
							else
								if attached utf_8_encoded (code) as l_utf_8 then
									on_content (l_utf_8, 0, l_utf_8.count - 1, parse_data)
								end
							end
					else
						if token < 0 then
							Result := scanned_error_code
							done := True  -- partial; wait for more data
						end
					end
					if not done then
						inspect c_accounting_source_type (parse_data)
							when Source_expansion then
								add_to_entity_expansion_count (parse_data, tok_end - index)

							when Source_expansion_with_checks then
								add_to_entity_expansion_count (parse_data, tok_end - index)
								if is_entity_expansion_limit_breached (parse_data) then
									Result := Error_amplification_limit_breach; done := True
								end

						else end
						index := tok_end
					end
				end
			end
			inspect Result when 0 then
				inspect c_accounting_source_type (parse_data) when Source_content then
					add_to_content_count (parse_data, index - buffer_index)
				else end
			else end
			buffer_index := index
		end

	process_entity (
		buf: like buffer; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST
		names: like name_cache; context: XT_ELEMENT_CONTEXT; parse_data: POINTER
		done: TYPED_POINTER [BOOLEAN]
	): INTEGER
		local
			buffer_index_copy, code, error: INTEGER; entity_name: XT_ENTITY_NAME; source_type: NATURAL_8
		do
			code := predefined_entity_code (buf, start_index, end_index)
			inspect code when -1 then
				entity_name := entity_cache.item (buf, start_index, end_index)
				if entity_name.is_unparsed then
					Result := Error_binary_entity_ref; put_boolean (done, True)

				elseif entity_name.is_open then
					Result := Error_recursive_entity_ref; put_boolean (done, True)

				elseif entity_name.has_external_id then
					if not on_external_entity_reference (entity_name, name_cache.entity_context (entity_name), parse_data) then
						Result := Error_external_entity_handling
					end

				elseif attached entity_table.item (entity_name) as entity_value then
					buffer_index_copy := buffer_index -- save field
					buffer_index := 0
					source_type := c_accounting_source_type (parse_data)
					entity_name.open
					update_accounting_source_type (parse_data)
					error := process_content (
						entity_value.area, 0, entity_value.count, attributes, names, context, parse_data
					)  -- Recurse

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

				elseif attributes.undefined_entities_permitted then
					on_skipped_entity (entity_name, False, parse_data)

				else
					Result := Error_undefined_entity; put_boolean (done, True)
				end
			else
				on_content (unescaped (code), 0, 0, parse_data)
			end
		end

feature {NONE} -- Implementation

	current_parser: XT_XML_PARSER_BASE
		do
			Result := Current
		end

	in_cdata_section: BOOLEAN
		do
			Result := parser_data.in_cdata_section
		end


feature {NONE} -- Internal attributes

	last_buffer_request_size: INTEGER

	partial_token_bytes_before: INTEGER

	parse_end_byte_index: INTEGER_64
		-- Cumulative count of bytes committed to the parser.

	reparse_deferral_enabled: BOOLEAN

invariant
	valid_state: Parsing_states.has (parsing_state)
	position_index_non_negative: position_index >= 0
	non_negative_byte_index: parse_end_byte_index >= 0
	partial_token_non_negative: partial_token_bytes_before >= 0

note
	notes: "[
		Ports XML_Parse(), XML_ParseBuffer(), XML_GetBuffer(), and callProcessor()
		from xmlparse.c (libexpat 2.x) to Eiffel with Design by Contract.

		Pointer arithmetic from the C source is replaced by integer indices
		into `buffer: SPECIAL [CHARACTER]'.  The correspondences are:

		  C field              Eiffel attribute
		  -----------------------------------------------------------------------
		  m_buffer[0]          buffer [0]
		  m_bufferPtr          buffer_ptr        (index)
		  m_bufferEnd          buffer_end        (index)
		  m_bufferLim          buffer_lim        (capacity)
		  m_parseEndPtr        parse_end_ptr     (index, snapshot at parse entry)
		  m_positionPtr        position_ptr      (index for line/col tracking)
		  m_parseEndByteIndex  parse_end_byte_index
		  m_handlerCallDepth   handler_call_depth
		  m_partialTokenBytesBefore  partial_token_bytes_before
		  m_lastBufferRequestSize    last_buffer_request_size
		  m_reparseDeferralEnabled   reparse_deferral_enabled
		  m_parsingStatus.parsing    parsing_state
		  m_parsingStatus.finalBuffer  is_final_buffer
		  m_errorCode          error_code

		Deferred features that concrete subclasses must supply:
			on_comment (text: C_STRING_8)
			on_content (text_intervals: XT_STRING_INTERVALS)
			on_tag_attributes
			on_tag_end (name: STRING_8)
			on_tag_start (name: STRING_8; is_empty: BOOLEAN)


		Optional features that concrete subclasses can redefine:
			on_start_parsing     	-- initialise hash salt, namespace context (startParsing)
			on_clear_reenter     	-- clear the reenter flagon_finish (status: INTEGER)
			on_set_error_processor  -- switch to errorProcessor sink
			on_update_position   	-- run XmlUpdatePosition over consumed bytes
	]"

end
