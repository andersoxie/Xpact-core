note
	description: "Xpact event handling interface"

	notes: "See end of class"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-08-12 07:00:00 GMT (Wednesday 12th August 2026)"
	revision: "1"

deferred class
	XT_PARSE_EVENTS

feature -- Contract support

	c_entity_handled (parse_data: POINTER): BOOLEAN
		deferred
		end

	valid_entity_ref (entity_ref: STRING): BOOLEAN
		do
			if entity_ref.count >= 3 then
				inspect entity_ref [1]
					when '&', '%%' then
						Result := entity_ref [entity_ref.count] = ';'
				else
				end
			end
		end

feature {NONE} -- Event handlers

	on_clear_reenter
			-- Clear the reenter flag after each loop iteration.
		do
		ensure
			cleared: not processor_wants_reenter
		end

	on_finish (a_status: INTEGER)
		do
		end

	on_start_parsing: BOOLEAN
			-- Called once when a root parser leaves State_initialized.
			-- Initialise hash salt and any implicit namespace context here.
			-- Return True on success; False causes the parse to abort with
			-- Error_no_memory (matching startParsing() in xmlparse.c).
		do
			Result := True
		end

	on_set_error_processor
		-- Switch the active processor to the error sink so that any
		-- further parse calls immediately fail.
		-- Corresponds to `m_processor = errorProcessor' in xmlparse.c.
		do
		end

	on_update_position (start_index, end_index: INTEGER)
			-- Update line/column counters by scanning
			-- `buffer [start_index .. end_index)'.
			-- Corresponds to XmlUpdatePosition() calls in xmlparse.c.
		require
			valid_range: start_index >= 0 and then start_index <= end_index
			to_in_buf: end_index <= buffer_end
		do
		end

feature {XT_NAMESPACE_SCOPE} -- Declaration event handlers

	on_attribute_list_declaration (parts_list: XT_ATTRIBUTE_PARTS_LIST; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_AttlistDeclHandler)(
		--   void *userData, const XML_Char *elname, const XML_Char *attname,
		--   const XML_Char *att_type, const XML_Char *dflt, int isrequired);
		require
			parts_list_completed: parts_list.is_complete
		deferred
		end

	on_doctype_declaration_start (parts_list: XT_DOCUMENT_TYPE_PARTS_LIST; has_internal_subset: BOOLEAN; parse_data: POINTER)
		-- typedef void (
		-- 	XMLCALL *XML_StartDoctypeDeclHandler)(void *userData,
 		-- 	const XML_Char *doctypeName, const XML_Char *sysid, const XML_Char *pubid, int has_internal_subset);

		deferred
		end

	on_element_declaration (name: STRING; model: XT_ELEMENT_PARTICLE; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_ElementDeclHandler)(void *userData, const XML_Char *name, XML_Content *model);
		deferred
		end

	on_entity_declaration (parts: XT_ENTITY_PARTS_I; parse_data: POINTER)

		-- typedef void(XMLCALL *XML_EntityDeclHandler)(
		-- 	void *userData, const XML_Char *entityName, int is_parameter_entity,
		-- 	const XML_Char *value, int value_length, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId,
		-- 	const XML_Char *notationName);
		require
			valid_entity_reference: valid_entity_ref (parts.name)
		deferred
		end

	on_namespace_declaration_end (prefix: STRING; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_EndNamespaceDeclHandler) (
		-- 	void *userData, const XML_Char *prefix);
		deferred
		end

	on_namespace_declaration_start (prefix, uri: STRING; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_StartNamespaceDeclHandler) (
		-- 	void *userData, const XML_Char *prefix, const XML_Char *uri);
		deferred
		end

	on_notation_declaration (parts: XT_NOTATION_PARTS_LIST; parse_data: POINTER)
		-- typedef void(XMLCALL *XML_NotationDeclHandler)(void *userData,
		-- const XML_Char *notationName, const XML_Char *base, const XML_Char *systemId, const XML_Char *publicId);
		deferred
		end

	on_unparsed_entity_declaration (parts: XT_ENTITY_PARTS_I; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_UnparsedEntityDeclHandler) (
		-- 	void *userData, const XML_Char *entityName, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId, const XML_Char *notationName);
		require
			entity_handled_reset: not c_entity_handled (parse_data)
			valid_entity_reference: valid_entity_ref (parts.name)
		deferred
		end

	on_xml_declaration (buf: like buffer; attributes: XT_ATTRIBUTE_LIST; parse_data: POINTER)
		require
			valid_attribute_indices_count: attributes.is_valid_count
		deferred
		end

feature {NONE} -- Other parse events

	on_default (buf: SPECIAL [CHARACTER]; start_index, end_index: INTEGER; parse_data: POINTER)
		-- typedef void (XMLCALL *XML_DefaultHandler) (void *userData, const XML_Char *s, int len);
		deferred
		end

	on_external_entity_reference (entity: XT_EXTERNAL_IDENTITY_I; context: detachable STRING; parse_data: POINTER): BOOLEAN
		-- typedef int (XMLCALL *XML_ExternalEntityRefHandler) (
		-- 	XML_Parser parser, const XML_Char *context, const XML_Char *base,
		-- 	const XML_Char *systemId, const XML_Char *publicId);
		deferred
		end

	on_not_standalone (parse_data: POINTER): INTEGER
		-- typedef int (XMLCALL *XML_NotStandaloneHandler) (void *userData);
		deferred
		end

	on_skipped_entity (entity_name: STRING; is_parameter_entity: BOOLEAN; parse_data: POINTER)
		-- This is called in two situations:
		-- 1) An entity reference is encountered for which no declaration has been
		--    read but it is not an error.
		-- 2) An internal entity reference is read, but not expanded, because
		--    XML_SetDefaultHandler has been called.

		-- typedef void (XMLCALL *XML_SkippedEntityHandler) (
		-- 	void *userData, const XML_Char *entityName, int is_parameter_entity);
		require
			valid_entity_reference: valid_entity_ref (entity_name)
		deferred
		end

	on_unknown_encoding (name: STRING; parse_data: POINTER): detachable XT_CUSTOM_ENCODING_I
		-- typedef int (XMLCALL *XML_UnknownEncodingHandler) (
		-- 	void *encodingHandlerData, const XML_Char *name, XML_Encoding *info);
		deferred
		end

feature {NONE} -- Parse event handlers

	on_cdata_section_start (parse_data: POINTER)
		deferred
		end

	on_cdata_section_end (parse_data: POINTER)
		deferred
		end

	on_comment (buf: like buffer; start_index, end_index: INTEGER; parse_data: POINTER)
		deferred
		end

	on_content (buf: like buffer; start_index, end_index: INTEGER; parse_data: POINTER)
		deferred
		end

	on_element_end (name: STRING_8; parse_data: POINTER)
		deferred
		end

	on_element_start (buf: like buffer; context: XT_ELEMENT_CONTEXT; attributes: XT_ATTRIBUTE_LIST; token: INTEGER; parse_data: POINTER)
		require
			valid_token: element_tokens.has (token)
			valid_attribute_indices_count: attributes.is_valid_count
		deferred
		end

	on_processing_instruction (
		buf: like buffer; start_index, end_index: INTEGER; attributes: XT_ATTRIBUTE_LIST; parse_data: POINTER
	)
		deferred
		end

feature {NONE} -- Implementation

	processor_wants_reenter: BOOLEAN
		-- True when the processor has set its reenter flag, requesting
		-- another pass through `process_content' to avoid stack overflow.
		-- Corresponds to `m_reenter' in xmlparse.c.
		do
			Result := False
		end

feature {NONE} -- Deferred

	buffer_end: INTEGER
		deferred
		end

	buffer: SPECIAL [CHARACTER_8]
		deferred
		end

	element_tokens: ARRAY [INTEGER]
		deferred
		end

note
	notes: "[
		**About XML_SkippedEntityHandler**

		This is called in two situations:
		1. An entity reference is encountered for which no declaration has been read and this is not an error.
		2. An internal entity reference is read, but not expanded, because XML_SetDefaultHandler has been called.

		Note: skipped parameter entities in declarations and skipped general entities in attribute values cannot
		be reported, because the event would be out of sync with the reporting of the declarations or attribute value.

		Does it also apply to parameter entities ?

		Partially: situation (1) applies to both, but situation (2) does not apply to parameter entities at all.

		**Situation 1**
		undefined entity, not an error: confirmed for both. General entities at xmlparse.c:3367 (content, &name;),
		and parameter entities at xmlparse.c:6046, explicitly gated on role == XML_ROLE_PARAM_ENTITY_REF, that's the %name; case.

		**Situation 2**
		internal entity read but not expanded because XML_SetDefaultHandler was called: this hinges entirely on the
		m_defaultExpandInternalEntities flag, and that flag is checked in exactly one place in the whole file
		(xmlparse.c:3381), inside the general-entity-reference-in-content path (the same block as call site #1 above).
		There's no equivalent check anywhere in the parameter-entity handling code. So a known, internal parameter entity
		is always expanded regardless of whether XML_SetDefaultHandler or XML_SetDefaultHandlerExpand was called.
		There's no "skip instead of expand" path for %name; the way there is for &name;.

		So: parameter entities can trigger XML_SkippedEntityHandler only via situation (1) (undefined + not an error), never via situation (2).
	]"

end
