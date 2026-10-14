note
	description: "[
		Tokenizer for the XML prolog and DTD subset.

		Corresponds to prologTok, scanPercent, scanPoundName, scanLit
		in xmltok_impl.c.

		prologTok handles all tokens that appear before and inside the DTD:
		quoted literals, '<'-prefixed markup, whitespace, punctuation, and
		name/nmtoken tokens.  Negative return values signal partial tokens
		where the caller needs more data before deciding the token type:
		  -Tok_prolog_s          : CR at end of buffer (might be part of CRLF)
		  -Tok_close_bracket     : ']' at end of buffer
		  -Tok_close_paren       : ')' at end of buffer
		  -Tok_pound_name        : partial #name
		  -Tok_name / -Tok_nmtoken : partial name/nmtoken
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:36:24 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XT_PROLOG_SCANNER

inherit
	XT_SCANNER_BASE
	XT_REF_SCANNER
	XT_PI_COMMENT_SCANNER

	EL_TYPED_POINTER_ROUTINES_I

feature -- Prolog tokenization

	prolog_tok (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER): INTEGER
		-- Return the next prolog/DTD token.  Sets next_token_index.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index, tok, bt_code, byte_count: INTEGER; buf_ptr: POINTER
		do
			buf_ptr := buf.base_address; index := start_index
			if index >= end_index then
				Result := Tok_none
			else
				bt_code := c_byte_table_item (parse_data, buf [index].code)
				inspect bt_code
					when BT_quote then
						Result := scan_literal (buf, index + 1, end_index, BT_quote, buf_ptr, parse_data)

					when BT_apostrophe then
						Result := scan_literal (buf, index + 1, end_index, BT_apostrophe, buf_ptr, parse_data)

					when BT_lt then
						index := index + 1
						if index >= end_index then
							Result := Tok_partial
						else
							inspect c_byte_table_item (parse_data, buf [index].code)
								when BT_exclamation then
									Result := scan_decl (buf, index + 1, end_index, buf_ptr, parse_data)
								when BT_question then
									Result := scan_pi (buf, index + 1, end_index, buf_ptr, parse_data)
								when BT_name_start, BT_hex_digit, BT_non_ascii, BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
									next_token_index := index - 1
									Result := Tok_instance_start
							else
								next_token_index := index; Result := Tok_invalid
							end
						end
					when BT_CR then
						if index + 1 = end_index then
							next_token_index := end_index
							Result := -Tok_prolog_whitespace
						else
							Result := scan_prolog_whitespace (buf, index, end_index, buf_ptr, parse_data)
						end
					when BT_whitespace, BT_LF then
						Result := scan_prolog_whitespace (buf, index, end_index, buf_ptr, parse_data)
					when BT_percent then
						Result := scan_percent (buf, index + 1, end_index, buf_ptr, parse_data)
					when BT_comma then
						next_token_index := index + 1; Result := Tok_comma

					when BT_left_square_bracket then
						next_token_index := index + 1; Result := Tok_open_bracket

					when BT_right_square_bracket then
						index := index + 1
						if index >= end_index then
							next_token_index := index; Result := -Tok_close_bracket
						elseif buf [index] = ']' then
							if end_index - index < 2 * 1 then
								next_token_index := index; Result := Tok_partial
							elseif buf [index + 1] = '>' then
								next_token_index := index + 2
								Result := Tok_cond_sect_close
							else
								next_token_index := index; Result := Tok_close_bracket
							end
						else
							next_token_index := index; Result := Tok_close_bracket
						end
					when BT_left_parenthesis then
						next_token_index := index + 1; Result := tok_open_parenthesis
					when BT_right_parenthesis then
						index := index + 1
						if index >= end_index then
							next_token_index := index; Result := -tok_close_parenthesis
						else
							inspect c_byte_table_item (parse_data, buf [index].code)
								when BT_asterisk then
									next_token_index := index + 1; Result := Tok_close_paren_asterisk
								when BT_question then
									next_token_index := index + 1; Result := Tok_close_paren_question
								when BT_plus then
									next_token_index := index + 1; Result := Tok_close_paren_plus
								when BT_CR, BT_LF, BT_whitespace, BT_gt, BT_comma, BT_pipe_symbol, BT_right_parenthesis then
									next_token_index := index; Result := tok_close_parenthesis
							else
								next_token_index := index; Result := Tok_invalid
							end
						end
					when BT_pipe_symbol then
						next_token_index := index + 1; Result := Tok_or
					when BT_gt then
						next_token_index := index + 1; Result := Tok_decl_close
					when BT_hash then
						Result := scan_pound_name (buf, index + 1, end_index, buf_ptr, parse_data)
					when BT_name_start, BT_hex_digit then
						tok := Tok_name
						index := index + 1
						Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data)
					when BT_digit, BT_name_only, BT_minus then
						tok := tok_name_token
						index := index + 1
						Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data)

					when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						byte_count := bt_code - 3
						if end_index - index < byte_count then
							Result := Tok_partial_char
						elseif is_invalid_character (buf, index, byte_count) then
							next_token_index := index; Result := Tok_invalid
						elseif is_name_start_character (buf, index, byte_count) then
							tok := Tok_name; index := index + byte_count
							Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data)
						elseif is_name_character (buf, index, byte_count) then
							tok := tok_name_token; index := index + byte_count
							Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data)
						else
							next_token_index := index; Result := Tok_invalid
						end
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

feature -- Status query

	is_plausible_xml (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER): BOOLEAN
		-- `True' if characters from `start_index' to `end_index' are plausibly the start of an XML document
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			i, j, bt_code, byte_count: INTEGER; found_lt, found: BOOLEAN
		do
			i := start_index; newline_or_tab_found := False
			Result := True
		-- Skip white space until '<' found
			from until i >= end_index or found_lt or not Result loop
				if buf [i] = '<' then
					found_lt := True

				elseif not buf [i].is_space then
					Result := False
				else
					i := i + 1
				end
			end
			if Result and found_lt then
				check
					i_th_character_is_lt: buf [i] = '<'
				end
				Result := i + 4 <= end_index -- enough room for "<!DOC" or 4 byte UTF-8 sequence
				if Result then
					from j := 1 until j > Common_starts_with.count or found loop
						if starts_with (buf, i, Common_starts_with [j]) then
							found := True
						else
							j := j + 1
						end
					end
					if not found then
					-- check if start of tag
						i := i + 1
						bt_code := c_byte_table_item (parse_data, buf [i].code)
						inspect bt_code
							when BT_name_start, BT_hex_digit then
								do_nothing

							when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
								byte_count := bt_code - 3
								Result := not is_invalid_character (buf, i, byte_count)

						else
							Result := False
						end
					end
				end
			end
		end

	has_syntax_error (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER): BOOLEAN
		-- `True' if characters in `buf' from `start_index' to `end_index' appear to have a syntax error
		require
			valid_range: start_index <= end_index and end_index <= buf.count
		local
			index, tok, bt_code, byte_count: INTEGER; buf_ptr: POINTER
		do
			buf_ptr := buf.base_address; index := start_index
			if index < end_index then
				bt_code := c_byte_table_item (parse_data, buf [index].code)
				inspect bt_code
					when BT_quote then
						Result := scan_literal (buf, index + 1, end_index, BT_quote, buf_ptr, parse_data) = Tok_literal

					when BT_apostrophe then
						Result := scan_literal (buf, index + 1, end_index, BT_apostrophe, buf_ptr, parse_data) = Tok_literal

					when BT_lt then
						index := index + 1
						if index < end_index then
							inspect c_byte_table_item (parse_data, buf [index].code)
								when BT_exclamation then
									Result := scan_decl (buf, index + 1, end_index, buf_ptr, parse_data) = Tok_decl_open

								when BT_question then
									inspect scan_pi (buf, index + 1, end_index, buf_ptr, parse_data) when Tok_pi, Tok_xml_decl then
										Result := True
									else
										Result := False
									end

								when BT_name_start, BT_hex_digit, BT_non_ascii, BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
									next_token_index := index - 1
							else
								next_token_index := index; Result := Tok_invalid.to_boolean
							end
						end
					when BT_CR then
						if index + 1 = end_index then
							next_token_index := end_index
						else
							Result := scan_prolog_whitespace (buf, index, end_index, buf_ptr, parse_data) /= Tok_prolog_whitespace
						end
					when BT_whitespace, BT_LF then
						Result := scan_prolog_whitespace (buf, index, end_index, buf_ptr, parse_data) /= Tok_prolog_whitespace

					when BT_percent then
						inspect scan_percent (buf, index + 1, end_index, buf_ptr, parse_data)
							when Tok_param_entity_ref, Tok_percent then
								Result := True
						else
							Result := False
						end

					when BT_comma then
						next_token_index := index + 1; Result := True

					when BT_left_square_bracket then
						next_token_index := index + 1; Result := True

					when BT_right_square_bracket then
						index := index + 1
						if index >= end_index then
							next_token_index := index; Result := False
						elseif buf [index] = ']' then
							if end_index - index < 2 * 1 then
								next_token_index := index; Result := False
							elseif buf [index + 1] = '>' then
								next_token_index := index + 2
								Result := True
							else
								next_token_index := index; Result := True
							end
						else
							next_token_index := index; Result := False
						end
					when BT_left_parenthesis then
						next_token_index := index + 1; Result := True

					when BT_right_parenthesis then
						index := index + 1
						if index >= end_index then
							next_token_index := index; Result := False
						else
							inspect c_byte_table_item (parse_data, buf [index].code)
								when BT_asterisk then
									next_token_index := index + 1; Result := True
								when BT_question then
									next_token_index := index + 1; Result := True
								when BT_plus then
									next_token_index := index + 1; Result := True
								when BT_CR, BT_LF, BT_whitespace, BT_gt, BT_comma, BT_pipe_symbol, BT_right_parenthesis then
									next_token_index := index; Result := True
							else
								next_token_index := index; Result := False
							end
						end
					when BT_pipe_symbol then
						next_token_index := index + 1; Result := True

					when BT_gt then
						next_token_index := index + 1; Result := True

					when BT_hash then
						Result := scan_pound_name (buf, index + 1, end_index, buf_ptr, parse_data) = Tok_pound_name

					when BT_name_start, BT_hex_digit, BT_colon then
						tok := Tok_name
						index := index + 1
						Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data) = Tok_name

					when BT_digit, BT_name_only, BT_minus then
						tok := Tok_name_token
						index := index + 1
						Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data) = Tok_name_token

					when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						byte_count := bt_code - 3
						if end_index - index < byte_count then
							Result := Tok_partial_char.to_boolean
						elseif is_invalid_character (buf, index, byte_count) then
							next_token_index := index; Result := Tok_invalid.to_boolean
						elseif is_name_start_character (buf, index, byte_count) then
							tok := Tok_name; index := index + byte_count
							Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data) = Tok_name

						elseif is_name_character (buf, index, byte_count) then
							tok := Tok_name_token; index := index + byte_count
							Result := scan_name_or_name_token (buf, index, end_index, tok, buf_ptr, parse_data) = Tok_name_token
						else
							next_token_index := index; Result := False
						end
				else
					next_token_index := index; Result := False
				end
			end
		end

feature {NONE} -- Prolog sub-scanners

	scan_percent (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
			-- Scan parameter entity reference after '%'.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= end_index then
				Result := Tok_partial

			else
				inspect c_byte_type_code (parse_data, buf_ptr + index)
					when BT_name_start, BT_hex_digit then
						index := index + 1
						from until index >= end_index or done loop
							inspect c_byte_type_code (parse_data, buf_ptr + index)
								when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus then
									index := index + 1
								when BT_semicolon then
									next_token_index := index + 1
									Result := Tok_param_entity_ref; done := True
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
						end
						if not done then
							Result := Tok_partial
						end
					when BT_whitespace, BT_LF, BT_CR, BT_percent then
						next_token_index := index; Result := Tok_percent

				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

	scan_pound_name (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
			-- Scan #name after '#'.  Negative result means partial token.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= end_index then
				Result := Tok_partial

			else
				inspect c_byte_type_code (parse_data, buf_ptr + index)
					when BT_name_start, BT_hex_digit then
						index := index + 1
						from until index >= end_index or done loop
							inspect c_byte_type_code (parse_data, buf_ptr + index)
								when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus then
									index := index + 1
								when BT_CR, BT_LF, BT_whitespace, BT_right_parenthesis, BT_gt, BT_percent, BT_pipe_symbol then
									next_token_index := index; Result := Tok_pound_name; done := True
							else
								next_token_index := index; Result := Tok_invalid; done := True
							end
						end
						if not done then
							next_token_index := index; Result := -Tok_pound_name
						end
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

	scan_literal (buf: SPECIAL [CHARACTER]; start_index, end_index, a_open: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
		-- Scan quoted literal (attribute or entity value delimited by
		-- a_open quote type BT_quote or BT_apostrophe).
		-- Returns Tok_literal or negative (partial) or Tok_invalid.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index, bt_code, byte_count: INTEGER; done: BOOLEAN
		do
			index := start_index; newline_or_tab_found := False
			from until index >= end_index or done loop
				bt_code := c_byte_type_code (parse_data, buf_ptr + index)
				inspect bt_code
					when BT_non_xml, BT_malform, BT_continuation_byte then
						next_token_index := index; Result := Tok_invalid; done := True

					when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						byte_count := bt_code - 3
						if end_index - index < byte_count then
							Result := Tok_partial_char; done := True

						elseif is_invalid_character (buf, index, byte_count) then
							next_token_index := index; Result := Tok_invalid; done := True
						else
							index := index + byte_count
						end
					when BT_LF, BT_CR then
						newline_or_tab_found := True
						index := index + 1

					when BT_quote, BT_apostrophe then
						index := index + 1
						if bt_code = a_open then
							if index >= end_index then
								Result := Tok_literal.opposite; done := True
							else
								next_token_index := index
								inspect c_byte_type_code (parse_data, buf_ptr + index)
									when BT_whitespace, BT_CR, BT_LF, BT_gt, BT_percent, BT_left_square_bracket then
										Result := Tok_literal
								else
									Result := Tok_invalid
								end
								done := True
							end
						end
				else
					index := index + 1
				end
			end
			if not done then
				Result := Tok_partial
			end
		end

	scan_prolog_whitespace (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
		-- Collect whitespace run and return `Tok_prolog_whitespace'.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index: INTEGER
		do
			index := start_index
			from index := index + 1 until index >= end_index loop
				inspect c_byte_type_code (parse_data, buf_ptr + index)
					when BT_whitespace, BT_LF then
						index := index + 1
					when BT_CR then
						if index + 1 = end_index then
							index := end_index  -- exit; might be CRLF
						else
							index := index + 1
						end
				else
					next_token_index := index; Result := Tok_prolog_whitespace; index := end_index
				end
			end
			if Result = 0 then
				next_token_index := index; Result := Tok_prolog_whitespace
			end
		end

	scan_name_or_name_token (
		buf: SPECIAL [CHARACTER]; start_index, end_index, a_tok: INTEGER; buf_ptr, parse_data: POINTER
	): INTEGER
			-- Continue scanning a name or nmtoken started by caller.
			-- a_tok is Tok_name or Tok_nmtoken from the first character.
			-- Returns the token (possibly with suffix +, *, ?) or negative if partial.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index, tok, bt_code, byte_count: INTEGER; done: BOOLEAN
		do
			tok := a_tok; index := start_index
			from until index >= end_index or done loop
				bt_code := c_byte_type_code (parse_data, buf_ptr + index)
				inspect bt_code
					when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus, BT_colon then
						index := index + 1

					when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						byte_count := bt_code - 3
						if end_index - index < byte_count then
							Result := Tok_partial_char; done := True

						elseif is_invalid_character (buf, index, byte_count) then
							next_token_index := index
							Result := Tok_invalid; done := True
						else
							index := index + byte_count
						end

					when BT_gt, BT_right_parenthesis, BT_comma, BT_pipe_symbol, BT_left_square_bracket,
						BT_percent, BT_whitespace, BT_CR, BT_LF then
						next_token_index := index; Result := tok; done := True

					when BT_plus then
						if tok = tok_name_token then
							next_token_index := index; Result := Tok_invalid
						else
							next_token_index := index + 1; Result := Tok_name_plus
						end
						done := True

					when BT_asterisk then
						if tok = tok_name_token then
							next_token_index := index; Result := Tok_invalid
						else
							next_token_index := index + 1; Result := Tok_name_asterisk
						end
						done := True
					when BT_question then
						if tok = tok_name_token then
							next_token_index := index; Result := Tok_invalid
						else
							next_token_index := index + 1; Result := Tok_name_question
						end
						done := True
				else
					next_token_index := index; Result := Tok_invalid; done := True
				end
			end
			if not done then
				next_token_index := index; Result := -tok
			end
		end

	scan_name (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
		-- check if `buf' from `start_index .. end_index' is a valid name
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index, bt_code, byte_count: INTEGER; done: BOOLEAN
		do
			index := start_index
			Result := Tok_name
			from until index >= end_index or done loop
				bt_code := c_byte_type_code (parse_data, buf_ptr + index)
				inspect bt_code
					when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus, BT_colon then
						index := index + 1

					when BT_non_xml, BT_malform, BT_continuation_byte then
						next_token_index := index; Result := Tok_invalid; done := True

					when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						byte_count := bt_code - 3
						if end_index - index < byte_count then
							Result := Tok_partial_char; done := True

						elseif is_invalid_character (buf, index, byte_count) then
							Result := Tok_invalid; done := True

						elseif index = start_index and then not is_name_start_character (buf, index, byte_count) then
							Result := Tok_invalid; done := True

						elseif not is_name_character (buf, index, byte_count) then
							Result := Tok_invalid; done := True

						else
							index := index + byte_count
						end
				else
					done := True
				end
			end
			inspect Result
				when Tok_name then
					next_token_index := index
			else
			end
		end

end
