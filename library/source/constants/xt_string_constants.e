note
	description: "XML document string constants"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-07-11 13:14:40 GMT (Saturday 11th July 2026)"
	revision: "1"

class
	XT_STRING_CONSTANTS

feature {STRING_HANDLER} -- Standard strings

	Cdata_lsqb: STRING = "CDATA["

	Comment_declaration: STRING = "<!--"

	Default_uri_key: STRING = "<default>"
		-- key for when xmlns attribute does not have a local name
		-- eg. <root xmlns="http://names.com/">

	PI_ending: STRING = "?>"

	Quote_marks: STRING = "'%""

	Xml_lower: STRING = "xml"

	Xmlns: STRING = "xmlns"

	Xml_namespace_uri: STRING = "http://www.w3.org/XML/1998/namespace"

feature {NONE} -- Document definition strings

	Common_starts_with: LIST [STRING]
		-- common leading strings at start of document after initial white space
		local
			s: XT_STRING_8_ROUTINES
		once
			Result := s.to_list ("<?xml, <!DOC, <!--", ',')
		end

	Http: STRING = "http"

	Unknown_id: STRING = "Unknown"

feature {NONE} -- XML declaration

	Valid_yes_no: ARRAY [STRING]
		once
			Result := << "yes", "no" >>
			Result.compare_objects
		end

end
