note
	description: "[
		Scanners for processing instructions, comments, CDATA section openers,
		and declaration keywords (<!foo).

		Corresponds to scanComment, scanDecl, scanPi, checkPiTarget, scanCdataSection in xmltok_impl.c.
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 20:45:44 GMT (Saturday 20th June 2026)"
	revision: "1"

deferred class XT_PI_COMMENT_SCANNER

inherit
	XT_SCANNER_BASE

feature {NONE} -- PI and comment scanning

	scan_comment (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
			-- Scan comment after '<!-'.  Returns Tok_comment or error.
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index, byte_count, bt_code: INTEGER; done: BOOLEAN
		do
			index := start_index
			if index >= end_index then
				Result := Tok_partial
			elseif c_read_character_8 (buf_ptr, index) /= '-' then
				next_token_index := index
				Result := Tok_invalid

			else
				index := index + 1
				from until index >= end_index or done loop
					bt_code := c_byte_type_code (parse_data, buf_ptr + index)
					inspect bt_code
						when BT_minus then
							index := index + 1
							if index >= end_index then
								Result := Tok_partial; done := True
							elseif c_read_character_8 (buf_ptr, index) = '-' then
								index := index + 1
								if index >= end_index then
									Result := Tok_partial; done := True

								else
									inspect c_read_character_8 (buf_ptr, index) when '>' then
										next_token_index := index + 1
										Result := Tok_comment; done := True
									else
										next_token_index := index; Result := Tok_invalid; done := True
									end
								end
							end
						when BT_non_xml, BT_malform, BT_continuation_byte then
							next_token_index := index; Result := Tok_invalid; done := True

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

						when BT_CR then
							index := index + 1

					else
						index := index + 1
					end
				end
				if not done then
					Result := Tok_partial
				end
			end
		end

	scan_pi (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
			-- Scan processing instruction after '<?'.
			-- Returns Tok_pi (or Tok_xml_decl if target is "xml").
		require
			valid_range: valid_range (buf, start_index, end_index)
		local
			index, token, bt_code, byte_count, error: INTEGER; target_start: INTEGER; done: BOOLEAN
			lower_upper: SPECIAL [INTEGER]
		do
			index := start_index; lower_upper := scanned_index_x4_buffer
			target_start := index
			if index >= end_index then
				Result := Tok_partial
			else
				bt_code := c_byte_type_code (parse_data, buf_ptr + index)
				inspect bt_code
					when BT_name_start, BT_hex_digit then
						index := index + 1

					when BT_non_xml, BT_malform, BT_continuation_byte then
						next_token_index := index; Result := Tok_invalid; done := True

					when BT_lead_2_byte, BT_lead_3_byte, BT_lead_4_byte then
						byte_count := bt_code - 3
						if end_index - index >= byte_count and then not is_invalid_character (buf, index, byte_count)
							and then is_name_start_character (buf, index, byte_count)
						then
							index := index + byte_count
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
				else
					next_token_index := index; Result := Tok_invalid; done := True
				end
				if not done then
					from until index >= end_index or done loop
						inspect c_byte_type_code (parse_data, buf_ptr + index)
							when BT_name_start, BT_hex_digit, BT_digit, BT_name_only, BT_minus then
								index := index + 1
							when BT_whitespace, BT_CR, BT_LF then
								token := check_pi_target (buf, target_start, index)
								if token = 0 then
									next_token_index := index; Result := Tok_invalid; done := True
								else
									inspect token when Tok_pi then
										lower_upper.extend (start_index)
										lower_upper.extend (index - 1)
										Result := scan_pi_content (buf, index + 1, end_index, token, buf_ptr, parse_data, lower_upper)
										done := True
										inspect lower_upper.count when 4 then
										-- 0 for `colon_index' argument
											error := attribute_list.transfer (buf, lower_upper, 0, scanned_entity_buffer)
										else
										end
									else
										Result := scan_pi_content (buf, index + 1, end_index, token, buf_ptr, parse_data, lower_upper)
										done := True
									end
								end
							when BT_question then
								token := check_pi_target (buf, target_start, index)
								if token = 0 then
									next_token_index := index; Result := Tok_invalid; done := True
								else
									index := index + 1
									if index >= end_index then
										Result := Tok_partial; done := True
									elseif c_read_character_8 (buf_ptr, index) = '>' then
										next_token_index := index + 1
										Result := token; done := True
									else
										next_token_index := index; Result := Tok_invalid; done := True
									end
								end
						else
							next_token_index := index; Result := Tok_invalid; done := True
						end
					end
					if not done then
						Result := Tok_partial
					end
				end
			end
			inspect Result when Tok_partial then
				attribute_list.wipe_out
			else end
		end

	scan_decl (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER): INTEGER
			-- Scan declaration keyword after '<!'.  Returns Tok_decl_open or error.
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
					when BT_minus then
						Result := scan_comment (buf, index + 1, end_index, buf_ptr, parse_data)

					when BT_left_square_bracket then
						next_token_index := index + 1
						Result := Tok_cond_sect_open

					when BT_name_start, BT_hex_digit then
						index := index + 1
						from until index >= end_index or done loop
							inspect c_byte_type_code (parse_data, buf_ptr + index)
								when BT_name_start, BT_hex_digit then
									index := index + 1
								when BT_whitespace, BT_CR, BT_LF, BT_percent then
									next_token_index := index
									Result := Tok_decl_open; done := True
							else
								next_token_index := index
								Result := Tok_invalid; done := True
							end
						end
						if not done then
						Result := Tok_partial
				end
				else
					next_token_index := index; Result := Tok_invalid
				end
			end
		end

	scan_cdata_section_open (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): INTEGER
			-- Verify 'CDATA[' after '<!['.  Returns Tok_cdata_sect_open or error.
		require
			valid_range: valid_range (buf, start_index, end_index)
		do
			if end_index - start_index < Cdata_lsqb.count then
				Result := Tok_partial
			else
				if starts_with (buf, start_index, Cdata_lsqb) then
					Result := Tok_cdata_sect_open
					next_token_index := start_index + Cdata_lsqb.count
				else
					Result := Tok_invalid
					next_token_index := start_index + match_count (buf, start_index, Cdata_lsqb) + 1
				end
			end
		end

feature {NONE} -- PI helpers

	check_pi_target (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): INTEGER
			-- Return Tok_xml_decl if target is exactly "xml" (case-sensitive),
			-- Tok_pi otherwise, or 0 if target is a case variation of "xml"
			-- (forbidden by XML spec: "<?XML" etc. are reserved).
		do
			if end_index - start_index = 3 then
				inspect buf [start_index] when 'x' then
					if same_characters (buf, start_index, start_index + 2, Xml_lower) then
						Result := Tok_xml_decl
					elseif same_caseless_characters (buf, start_index, start_index + 2, Xml_lower) then
						Result := 0 -- reserved; caller treats as invalid
					else
						Result := Tok_pi
					end
				else
					Result := Tok_pi
				end
			else
				Result := Tok_pi
			end
		end

	scan_pi_content (
		buf: SPECIAL [CHARACTER]; a_start_index, end_index, token: INTEGER
		buf_ptr, parse_data: POINTER; lower_upper: SPECIAL [INTEGER]
	): INTEGER
			-- Scan PI content until '?>'.  Returns token (Tok_pi or Tok_xml_decl).
		local
			index, start_index, bt_code, byte_count: INTEGER; done, passed_leading: BOOLEAN
		do
			from index := a_start_index until index > end_index or passed_leading loop
				inspect c_read_character_8 (buf_ptr, index) when '%T', '%N', '%/32/' then
					index := index + 1
				else
					passed_leading := True
				end
			end
			start_index := index
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
					when BT_question then
						inspect token when Tok_xml_decl then
							buf [index] := '/' -- turn into empty element to collect declaration attributes
							Result := scan_attributes (buf, start_index, index + 2, buf_ptr, parse_data, attribute_list)
							buf [index] := '?' -- revert
							inspect token when Tok_invalid then
								do_nothing
							else
								Result := Tok_xml_decl
							end
							done := True
						else
							index := index + 1
							if index >= end_index then
								Result := Tok_partial; done := True
							elseif c_read_character_8 (buf_ptr, index) = '>' then
								inspect token when Tok_pi then
									lower_upper.extend (start_index)
									lower_upper.extend (index - 2)
								else end
								next_token_index := index + 1
								Result := token; done := True
							end
						end
				else
					index := index + 1
				end
			end
			if not done then
				Result := Tok_partial
			end
			inspect Result when Tok_partial then
				lower_upper.wipe_out
			else end
		end

	scan_attributes (
		buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; buf_ptr, parse_data: POINTER
		attributes: XT_ATTRIBUTE_LIST

	): INTEGER
		deferred
		end

end
