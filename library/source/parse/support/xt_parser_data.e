note
	description: "[
		Allocated memory for `struct XML_ParserStruct' defined in
			
			contrib/xpact/include/xpact_private.h
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-09-16 09:20:00 GMT (Wednesday 16th September 2026)"
	revision: "1"

class
	XT_PARSER_DATA

inherit
	EL_ALLOCATED_C_OBJECT
		rename
			make_default as make_allocated
		end

	XT_C_PARSER_STRUCT
		rename
			c_size_of_parser_struct as c_size_of
		undefine
			copy, is_equal
		end

	XT_C_EXPANSION_ACCOUNTING_STRUCT
		undefine
			copy, is_equal
		end

	XT_NAMING_MODE_CONSTANTS
		export
			{ANY} Valid_naming_modes
		undefine
			copy, is_equal
		end

	XT_PARSE_CONSTANTS
		export
			{ANY} Valid_parameter_entity_parsing_status
		undefine
			copy, is_equal
		end

create
	make, make_default, make_shared

feature {NONE} -- Initialization

	make_default
		do
			make (NM_prefix_SEP_localname, '%U')
		end

	make (a_naming_mode: INTEGER; separator: CHARACTER_8)
		require
			valid_naming_mode: Valid_naming_modes.has (a_naming_mode)
		do
			make_allocated
			set_naming_mode (a_naming_mode, separator)
			set_defaults
			set_parameter_entity_parsing (PE_parsing_never)
			fill_byte_type_table
		end

feature -- Element change

	fill_byte_type_table
		-- Initialize combined ASCII + UTF-8 upper byte classification table.
		-- int byte_type_table [256];
		local
			ascii_table: SPECIAL [INTEGER]; i: INTEGER; ptr: POINTER
		do
			create ascii_table.make_filled (0, 128)
			fill_utf_8_ascii_half (ascii_table)
			ptr := self_ptr
			from i := 0 until i > 127 loop
				put_byte_table (ptr, i, ascii_table [i])
				i := i + 1
			end
			-- 0x80-0xBF: continuation bytes
			fill_byte_type_range (ptr, 8, 128, 191)   -- BT_continuation_byte = 8
			-- 0xC0 .. 0xDF: 2-byte lead bytes (is_invalid_char_2 catches 0xC0, 0xC1)
			fill_byte_type_range (ptr, 5, 192, 223)   -- BT_lead_2_byte = 5
			-- 0xE0 .. 0xEF: 3-byte lead bytes
			fill_byte_type_range (ptr, 6, 224, 239)   -- BT_lead_3_byte = 6
			-- 0xF0 .. 0xF4: 4-byte lead bytes
			fill_byte_type_range (ptr, 7, 240, 244)   -- BT_lead_4_byte = 7
			-- 0xF50xFD: not valid UTF-8 lead bytes
			fill_byte_type_range (ptr, 0, 245, 253)   -- BT_non_xml = 0
			-- 0xFE .. 0xFF: malformed
			put_byte_table (ptr, 254, 1)
			put_byte_table (ptr, 255, 1) -- BT_malform = 1
		end

	set_dtd_keep_processing (flag: BOOLEAN)
		do
			c_set_dtd_keep_processing (self_ptr, flag)
		end

	set_defaults
		do
			set_has_dtd_section (self_ptr, False)
			set_handler_call_depth (self_ptr, 0)
			set_in_prolog_section (self_ptr, True)
			set_in_cdata_section (self_ptr, False)
			set_in_dtd_section (self_ptr, False)
			set_dtd_keep_processing (True)
			set_standalone (False)

			c_set_accounting_source_type (self_ptr, Source_content)
			c_set_accounting_content_count (self_ptr, 1) -- prevent divide by zero error
			c_set_entity_expansion_count (self_ptr, 0)
		end

	set_naming_mode (a_naming_mode: INTEGER; separator: CHARACTER)
		do
			c_set_naming_mode (self_ptr, a_naming_mode, separator)
		ensure
			naming_mode_set: naming_mode = a_naming_mode
		end

	set_exponential_expansion_threshold (threshold_count: NATURAL_64)
		do
			c_set_exponential_expansion_threshold (self_ptr, threshold_count)
		end

	set_max_expansion_proportion (value: REAL_32)
		do
			c_set_max_expansion_proportion (self_ptr, value)
		end

	set_parameter_entity_parsing (status: INTEGER)
		-- set status of parameter entity parsing (always, never or unless_standalone)
		require
			valid_parsing_status: Valid_parameter_entity_parsing_status.has (status)
		do
			c_set_parameter_entity_parsing (self_ptr, status)
		end

	set_standalone (yes: BOOLEAN)
		do
			c_set_standalone (self_ptr, yes)
		end

feature -- Access

	naming_mode: INTEGER
		do
			Result := c_naming_mode (self_ptr)
		end

	namespace_separator: CHARACTER
		do
			Result := c_namespace_separator (self_ptr)
		end

	new_element_context: XT_ELEMENT_CONTEXT
		do
			create Result.make (self_ptr)
		end

	parameter_entity_parsing: INTEGER
		do
			Result := c_parameter_entity_parsing (self_ptr)
		end

	protocol_encoding_name: detachable STRING
		-- custom encoding name that will over-ride encoding attribute in <?xml?>
		-- declaration
		local
			ptr: POINTER
		do
			ptr := c_protocol_encoding_name (self_ptr)
			if is_attached (ptr) then
				create Result.make_from_c (ptr)
			end
		end

feature -- Measurement

	handler_call_depth: NATURAL
		do
			Result := c_handler_call_depth (self_ptr)
		end

	max_expansion_proportion: DOUBLE
		do
			Result := c_max_expansion_proportion (self_ptr)
		end

	content_count: NATURAL_64
		do
			Result := c_accounting_content_count (self_ptr)
		end

feature -- Status query

	is_standalone: BOOLEAN
		do
			Result := c_is_standalone (self_ptr)
		end

	in_prolog_section: BOOLEAN
		do
			Result := c_in_prolog_section (self_ptr)
		end

	is_param_entity_parsing_enabled: BOOLEAN
		do
			Result := c_param_entity_parsing_enabled (self_ptr)
		end

	in_cdata_section: BOOLEAN
		do
			Result := c_in_cdata_section (self_ptr)
		end

	undefined_entities_permitted: BOOLEAN
		do
			if not is_standalone then
				Result := c_has_parameter_entity_reference (self_ptr)
			end
		end

feature {NONE} -- Implementation

	fill_byte_type_range (struct_ptr: POINTER; type, start_index, end_index: INTEGER)
		local
			i: INTEGER
		do
			from i := start_index until i > end_index loop
				put_byte_table (struct_ptr, i, type)
				i := i + 1
			end
		end

	fill_utf_8_ascii_half (a: SPECIAL [INTEGER])
		-- Fill entries 0..127 with byte_type_table values
		require
			valid_array_size: a.count = 128
		do
			-- 0x00-0x08, 0x0B-0x0C, 0x0E-0x1F: BT_non_xml = 0 (make_filled default)
			a [9]  := 21; a [10] := 10; a [13] := 9   -- tab, LF, CR
			a [32] := 21; a [33] := 16; a [34] := 12; a [35] := 19
			a [36] := 28; a [37] := 30; a [38] := 3;  a [39] := 13
			a [40] := 31; a [41] := 32; a [42] := 33; a [43] := 34
			a [44] := 35; a [45] := 27; a [46] := 26; a [47] := 17
			a.fill_with (25, 48, 57)     -- BT_digit '0'..'9'
			a [58] := 23; a [59] := 18; a [60] := 2;  a [61] := 14
			a [62] := 11; a [63] := 15; a [64] := 28
			a.fill_with (24, 65, 70)     -- BT_hex_digit 'A'..'F'
			a.fill_with (22, 71, 90)     -- BT_name_start 'G'..'Z'
			a [91] := 20; a [92] := 28; a [93] := 4;  a [94] := 28
			a [95] := 22; a [96] := 28  -- '_', '`'
			a.fill_with (24, 97, 102)    -- BT_hex_digit 'a'..'f'
			a.fill_with (22, 103, 122)   -- BT_name_start 'g'..'z'
			a [123] := 28; a [124] := 36; a [125] := 28
			a [126] := 28; a [127] := 28
		end
end
