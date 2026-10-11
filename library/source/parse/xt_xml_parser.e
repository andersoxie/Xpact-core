note
	description: "A native Eiffel XML parser based on a port of C eXpat"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-07-08 20:30:52 GMT (Wednesday 8th July 2026)"
	revision: "1"

deferred class
	XT_XML_PARSER

inherit
	XT_XML_PARSER_BASE
		rename
			on_attribute_list_declaration as on_base_attribute_list_declaration,
			on_content as on_base_content,
			on_comment as on_base_commment,
			on_default as on_base_default,
			on_external_entity_reference as on_base_external_entity_reference,
			on_namespace_declaration_end as on_base_namespace_declaration_end,
			on_namespace_declaration_start as on_base_namespace_declaration_start,
			on_not_standalone as on_base_not_standalone,
			on_element_declaration as on_base_element_declaration,
			on_element_start as on_base_start_element,
			on_element_end as on_base_end_element,
			on_processing_instruction as on_base_processing_instruction,
			on_skipped_entity as on_base_skipped_entity,
			on_unknown_encoding as on_base_unknown_encoding,
			on_unparsed_entity_declaration as on_base_unparsed_entity_declaration
		redefine
			make
		end

	XT_STRING_8_ROUTINES_I

feature {NONE} -- Initialisation

	make (parse_data: XT_PARSER_DATA)
		do
			Precursor (parse_data)
			create text_buffer.make (0)
		end

feature {NONE} -- Base event handlers

	on_cdata_section_start (parse_data: POINTER)
		do
		end

	on_cdata_section_end (parse_data: POINTER)
		do
			do_with_content (text_buffer)
		end

	on_base_attribute_list_declaration (parts_list: XT_ATTRIBUTE_PARTS_LIST; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_AttlistDeclHandler)(
		--   void *userData, const XML_Char *elname, const XML_Char *attname,
		--   const XML_Char *att_type, const XML_Char *dflt, int isrequired);
		do
		end

	on_base_commment (
		area: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER
	)
		do
			on_comment (new_substring (area, start_index, end_index))
		end

	on_base_content (
		area: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER
	)
		-- handle content section in `area' from index `start_index' to `end_index'
		local
			count, white_count: INTEGER
		do
			if attached text_buffer as text then
				if is_white_space_skipped then
					append_area (text, area, start_index, end_index)
				else
					count := end_index - start_index + 1
					white_count := leading_white_space (area, start_index, end_index)
					if white_count < count then
						append_area (text, area, start_index + white_count, end_index)
						is_white_space_skipped := True
					end
				end
				content_call_count := content_call_count + 1
			end
		end

	on_base_default (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_DefaultHandler) (
		-- 	void *userData, const XML_Char *s, int len);
		do
		end

	on_base_external_entity_reference (a_entity: XT_EXTERNAL_IDENTITY_I; context: detachable STRING; parse_data: POINTER): BOOLEAN
		-- typedef int (XMLCALL *XML_ExternalEntityRefHandler) (
		-- 	XML_Parser parser, const XML_Char *context, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId);
		do
		end

	on_base_namespace_declaration_end (prefix: STRING; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_EndNamespaceDeclHandler) (
		-- 	void *userData, const XML_Char *prefix
		-- );
		do
		end

	on_base_namespace_declaration_start (prefix, uri: STRING; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_StartNamespaceDeclHandler) (
		-- 	void *userData, const XML_Char *prefix, const XML_Char *uri
		-- );
		do
		end

	on_base_not_standalone (parse_data: POINTER): INTEGER
		-- typedef int (XMLCALL *XML_NotStandaloneHandler) (void *userData);
		do
		end

	on_base_skipped_entity (entity_name: STRING; is_parameter_entity: BOOLEAN; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_SkippedEntityHandler) (
		-- 	void *userData, const XML_Char *entityName, int is_parameter_entity);
		do
		end

	on_base_unknown_encoding (name: STRING; parse_data: POINTER): detachable XT_CUSTOM_ENCODING_I
		-- typedef int (XMLCALL *XML_UnknownEncodingHandler) (
		-- 	void *encodingHandlerData, const XML_Char *name, XML_Encoding *info);
		do
		end

	on_base_unparsed_entity_declaration (parts: XT_ENTITY_PARTS_I; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_UnparsedEntityDeclHandler) (
		-- 	void *userData, const XML_Char *entityName, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId, const XML_Char *notationName);
		do
		end

	on_base_element_declaration (name: STRING; model: XT_ELEMENT_PARTICLE; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_ElementDeclHandler)(void *userData, const XML_Char *name, XML_Content *model);
		do
		end

	on_base_processing_instruction (
		buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST; parse_data: POINTER
	)
		do
			if attributes.is_empty then
				on_processing_instruction (new_substring (buf, start_index, end_index), Empty_string)
			else
				on_processing_instruction (attributes.first_name, attributes.first_value (buf))
			end
		end

	on_base_start_element (
		buf: like buffer; context: XT_ELEMENT_CONTEXT; attributes: XT_ATTRIBUTE_LIST; token: INTEGER; parse_data: POINTER
	)
		do
			on_start_element (context.name, context.depth, attributes.as_table (buf, False))
		end

	on_base_end_element (name: STRING; parse_data: POINTER)
		do
			do_with_content (text_buffer)
			on_end_element (name)
		end

feature {NONE} -- Event handlers

	on_comment (text: STRING)
		deferred
		end

	on_content (text: STRING)
		deferred
		end

	on_start_element (name: STRING_8; depth: INTEGER; attribute_table: HASH_TABLE [STRING, STRING])
		deferred
		end

	on_end_element (name: STRING_8)
		deferred
		end

	on_processing_instruction (name, value: STRING)
		deferred
		end

feature {NONE} -- Implementation

	do_with_content (text: STRING_8)
		do
			inspect content_call_count when 0 then
				do_nothing
			else
				text.right_adjust
				if text.count > 0 then
					on_content (text)
					text.wipe_out
				end
				content_call_count := 0
				is_white_space_skipped := False
			end
		end

feature {NONE} -- Internal attributes

	content_call_count: INTEGER

	is_white_space_skipped: BOOLEAN

	text_buffer: STRING

end
