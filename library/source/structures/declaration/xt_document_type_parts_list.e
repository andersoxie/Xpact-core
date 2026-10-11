note
	description: "${XT_DECLARATION_PARTS_LIST} for `<!DOCTYPE ..>' declaration"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-08-26 10:16:00 GMT (Wednesday 26th August 2026)"
	revision: "1"

class
	XT_DOCUMENT_TYPE_PARTS_LIST

inherit
	XT_DECLARATION_PARTS_LIST
		undefine
			extend_external_id, make_external_id, try_set_external_id, wipe_out_external_id
		redefine
			is_valid
		end

	XT_EXTERNALLY_LINKABLE_DECLARATION
		rename
			make as make_external_id,
			wipe_out as wipe_out_external_id
		undefine
			copy, is_equal
		end

	XT_PARSE_ERROR_CONSTANTS
		undefine
			copy, is_equal
		end

create
	make

feature -- Access

	formal_public: detachable STRING
		-- 1st literal string after PUBLIC
		-- <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
		do
			if external_id_list.count > 0 then
				Result := external_id_list [0]
			end
		end

	uri: detachable STRING
		-- 2nd literal string after PUBLIC
		-- <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
		do
			if external_id_list.count = 2 then
				Result := external_id_list [1]
			end
		end

feature -- Status query

	is_valid: BOOLEAN
		do
			if count = 1 then
				inspect external_id_type when 0 then
					Result := True
				else
					Result := external_id_list.count = external_id_part_count
				end
			end
		end

feature -- Event handler

	on_document_type_end (prolog: XT_XML_PROLOG_PARSER): INTEGER
		local
			context: detachable STRING
		do
			if has_external_id and then prolog.parser_data.is_param_entity_parsing_enabled then
				if not prolog.on_external_entity_reference (Current, context, prolog.parser_data.self_ptr) then
					Result := Error_external_entity_handling
				end
			end
		end

end
