note
	description: "[
		Generate CRC-32 for one of XML document data types listed in ${XT_DATA_TYPES}.Data_type_table
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-06-29 6:31:14 GMT (Monday 29th June 2026)"
	revision: "1"

class
	XT_CRC_32_GENERATOR

inherit
	XT_XML_PARSER_BASE
		rename
			make as make_parser
		redefine
			make_parser, put_status, reset
		end

	XT_DEFAULT_PARSE_EVENTS
		rename
			on_cdata_section_start_ as on_cdata_section_start,
			on_cdata_section_end_ as on_cdata_section_end,
			on_element_end_ as on_element_end
		end

	XT_EXPAT_COMPARABLE_PARSER
		rename
			checksum as checksum_value
		redefine
			checksum_value
		end

	EL_CRC_32_CONSTANTS
		export
			{NONE} all
		end

	XT_DATA_TYPES

create
	make

feature {NONE} -- Initialisation

	make (parse_data: XT_PARSER_DATA; a_data_type: INTEGER)
		do
			make_parser (parse_data)
			data_type := a_data_type
		end

	make_parser (parse_data: XT_PARSER_DATA)
		do
			Precursor (parse_data)
			create checksum
		end

feature -- Access

	checksum: EL_CRC_32_DIGEST
		-- CRC-32/ISO-HDLC checksum

	checksum_value: NATURAL
		-- CRC-32/ISO-HDLC checksum
		do
			Result := checksum.value
		end

	new_benchmark (a_file_path: PATH; a_time_start: TIME; a_duration_ms, a_chunk_size: INTEGER): XT_CRC_32_BENCHMARK
		do
			create Result.make (Current, a_file_path, a_time_start, a_duration_ms, a_chunk_size)
			Result.set_data_type (data_type)
		end

feature -- Basic operations

	put_status (output: IO_MEDIUM)
		do
			output.put_string ("Checksum for " + data_type_name (data_type) + ": " + checksum.out)
			output.put_new_line
		end

feature -- Status change

	enable_trace
		do
			create {EL_TRACEABLE_CRC_32_DIGEST} checksum
		end

	reset
		do
			Precursor
			checksum.reset
		end

feature -- Status report

	trace_enabled: BOOLEAN

feature {NONE} -- Declaration event handlers

	on_attribute_list_declaration (parts_list: XT_ATTRIBUTE_PARTS_LIST; parse_data: POINTER)
		do
			inspect data_type when Type_decl_attribute_list then
				if attached checksum as crc and then attached parts_list.area as part then
					crc.add_string (part [0])
					crc.add_string (part [1])
					crc.add_string (part [2])
					crc.add_attached_string (parts_list.default_value)
					crc.add_boolean (parts_list.is_required)
				end
			else
			end
		end

	on_doctype_declaration_start (parts_list: XT_DOCUMENT_TYPE_PARTS_LIST; has_internal_subset: BOOLEAN; parse_data: POINTER)
		local
			i: INTEGER
		do
			inspect data_type when Type_decl_doctype then
				if attached checksum as crc and then attached parts_list.external_id_list as id_list then
					crc.add_string (parts_list.name)
					from i := 0 until i = id_list.count loop
						crc.add_string (id_list [i])
						i := i + 1
					end
					crc.add_boolean (has_internal_subset)
				end
			else end
		end

	on_element_declaration (name: STRING; model: XT_ELEMENT_PARTICLE; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_ElementDeclHandler)(void *userData, const XML_Char *name, XML_Content *model);
		do
			inspect data_type when Type_decl_element then
				if attached checksum as crc then
					crc.add_string (name)
					model.append_to_crc_32 (crc)
				end
			else end
		end

	on_entity_declaration (parts: XT_ENTITY_PARTS_I; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_EntityDeclHandler)(
		-- 	void *userData, const XML_Char *entityName, int is_parameter_entity,
		-- 	const XML_Char *value, int value_length, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId,
		-- 	const XML_Char *notationName);
		local
			base_ptr: POINTER
		do
			inspect data_type when Type_decl_entity then
				if not c_entity_handled (parse_data) and then attached checksum as crc then
					add_entity_name (crc, parts.name)
					crc.add_boolean (parts.is_parameter)
					if attached parts.value as str then
						crc.add_string (str)
						crc.add_integer_32 (str.count)
					end
					base_ptr := c_base (parse_data)
					if is_attached (base_ptr) then
						crc.add_bytes (base_ptr, c_string_8_length (base_ptr))
					end
					crc.add_attached_string (parts.system_id)
					crc.add_attached_string (parts.public_id)
					crc.add_attached_string (parts.notation_name)
				end
			else end
		end

	on_namespace_declaration_end (prefix: STRING; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_EndNamespaceDeclHandler) (
		-- 	void *userData, const XML_Char *prefix
		-- );
		do
			inspect data_type when Type_xmlns_declaration then
				if prefix.count > 0 then
					checksum.add_string (prefix)
				end
			else
			end
		end

	on_namespace_declaration_start (prefix, uri: STRING; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_StartNamespaceDeclHandler) (
		-- 	void *userData, const XML_Char *prefix, const XML_Char *uri
		-- );
		do
			inspect data_type when Type_xmlns_declaration then
				if attached checksum as crc then
					if prefix.count > 0 then
						crc.add_string (prefix)
					end
					crc.add_string (uri)
				end
			else
			end
		end

	on_notation_declaration (parts: XT_NOTATION_PARTS_LIST; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_NotationDeclHandler)(void *userData,
		-- const XML_Char *notationName, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId);
		local
			base_ptr: POINTER
		do
			inspect data_type when Type_decl_notation then
				if attached checksum as crc then
					crc.add_string (parts.name)
					base_ptr := c_base (parse_data)
					if is_attached (base_ptr) then
						crc.add_bytes (base_ptr, c_string_8_length (base_ptr))
					end
					crc.add_attached_string (parts.system_id)
					crc.add_attached_string (parts.public_id)
				end
			else end
		end

	on_unparsed_entity_declaration (parts: XT_ENTITY_PARTS_I; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_UnparsedEntityDeclHandler) (
		-- 	void *userData, const XML_Char *entityName, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId, const XML_Char *notationName);
		local
			base_ptr: POINTER
		do
			inspect data_type when Type_decl_entity then
				if attached checksum as crc then
					add_entity_name (crc, parts.name)
					base_ptr := c_base (parse_data)
					if is_attached (base_ptr) then
						crc.add_bytes (base_ptr, c_string_8_length (base_ptr))
					end
					crc.add_attached_string (parts.system_id)
					crc.add_attached_string (parts.public_id)
					crc.add_attached_string (parts.notation_name)
					set_entity_handled (parse_data, True)
				end
			else end
		end

	on_xml_declaration (buf: like buffer; attributes: XT_ATTRIBUTE_LIST; parse_data: POINTER)
		do
			inspect data_type when Type_xml_declaration then
				attributes.append_xml_declaration_to_crc_32 (buf, checksum)
			else end
		end

feature {NONE} -- Data event handlers

	on_comment (area: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER)
		do
			inspect data_type when Type_comment then
				checksum.add_characters (area, start_index, end_index)
			else
			end
		end

	on_content (area: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER)
		do
			inspect data_type
				when Type_cdata then
					if c_in_cdata_section (parse_data) then
						checksum.add_characters (area, start_index, end_index)
					end
				when Type_text then
					if not c_in_cdata_section (parse_data) then
						checksum.add_characters (area, start_index, end_index)
					end
			else
			end
		end

	on_element_start (
		buf: like buffer; context: XT_ELEMENT_CONTEXT; attributes: XT_ATTRIBUTE_LIST; token: INTEGER; parse_data: POINTER
	)
		do
			inspect data_type
				when Type_tag then
					checksum.add_string (context.name)

				when Type_attribute then
					inspect token when Tok_start_tag_with_attributes, Tok_empty_element_with_attributes then
						attributes.append_to_crc_32 (buf, context.default_attribute_values, checksum)
					else
					-- perhaps there are some default values defined in DTD prolog
						inspect attributes.count when 0 then
							if context.has_attributes then
								attributes.append_to_crc_32 (buf, context.default_attribute_values, checksum)
							end
						else end
					end
			else
			end
		end

	on_processing_instruction (
		buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST; parse_data: POINTER
	)
		do
			inspect data_type when Type_processing then
				if attributes.is_empty then
					checksum.add_characters (buf, start_index, end_index)
				else
					checksum.add_string (attributes.first_name)
					attributes.append_first_value_to_crc_32 (buf, checksum)
				end
			else
			end
		end

feature {NONE} -- Parse events

	on_default (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER)
		do
		end

	on_external_entity_reference (a_entity: XT_EXTERNAL_IDENTITY_I; a_context: detachable STRING; parse_data: POINTER): BOOLEAN
		-- typedef int (XMLCALL *XML_ExternalEntityRefHandler) (
		-- 	XML_Parser parser, const XML_Char *context, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId);
		local
			add_external_id: BOOLEAN
		do
			inspect data_type
				when Type_entity then
					if attached a_context as context then
						checksum.add_string (context)
						add_external_id := True
					end

				when Type_decl_entity then
					add_external_id := a_context = Void
			else
			end
			if add_external_id and then attached checksum as crc then
				crc.add_attached_string (a_entity.system_id)
				crc.add_attached_string (a_entity.public_id)
			end
			Result := True
		end

	on_not_standalone (parse_data: POINTER): INTEGER
		do
		end

	on_skipped_entity (entity_name: STRING; is_parameter_entity: BOOLEAN; parse_data: POINTER)
		do
			inspect data_type when Type_entity then
				if attached checksum as crc then
					add_entity_name (crc, entity_name)
					crc.add_boolean (is_parameter_entity)
				end
			else end
		end

	on_unknown_encoding (name: STRING; parse_data: POINTER): detachable XT_CUSTOM_ENCODING_I
		do
			if name ~ once "ISO-8859-15" then
				create {XT_LATIN_15_ENCODING} Result.make
			end
			inspect data_type when Type_xml_declaration then
				checksum.add_string (name)
			else end
		end

feature {NONE} -- Implementation

	add_entity_name (crc: like checksum; name: STRING)
		 -- exclude '&' and ';' from checksum
		require
			name_at_least_3_characters: name.count >= 3
		do
			crc.add_characters (name.area, 1, name.count - 2)
		end

feature {NONE} -- Internal attributes

	data_type: INTEGER

end
