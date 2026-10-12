note
	description: "Captilized keywords found in XML document type definition"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-10-12 09:46:00 GMT (Monday 12th October 2026)"
	revision: "1"

class
	XT_DTD_KEYWORDS

feature {NONE} -- Keywords

	ANY: STRING = "ANY"

	ATTLIST: STRING = "ATTLIST"

	CDATA: STRING = "CDATA"

	DOCTYPE: STRING = "DOCTYPE"

	ELEMENT: STRING = "ELEMENT"

	EMPTY: STRING = "EMPTY"

	ENTITY: STRING = "ENTITY"

	ENTITIES: STRING = "ENTITIES"

	ID: STRING = "ID"

	IDREF: STRING = "IDREF"

	IDREFS: STRING = "IDREFS"

	NDATA: STRING = "NDATA"

	NMTOKEN: STRING = "NMTOKEN"

	NMTOKENS: STRING = "NMTOKENS"

	NOTATION: STRING = "NOTATION"

	PUBLIC: STRING = "PUBLIC"

	SYSTEM: STRING = "SYSTEM"

feature {NONE} -- Constants

	Document_declarators: ARRAY [STRING]
		once
			Result := << DOCTYPE, ATTLIST, ELEMENT, ENTITY, NOTATION >>
			Result.compare_objects
		ensure
			valid_first: Result [{XT_PARSE_CONSTANTS}.DOCTYPE_] ~ DOCTYPE
			valid_last: Result [{XT_PARSE_CONSTANTS}.NOTATION_] ~ NOTATION
		end

	Valid_external_id_names: ARRAY [STRING]
		once
			Result := << PUBLIC, SYSTEM >>
		ensure
			valid_first: Result [{XT_PARSE_CONSTANTS}.ID_public] = PUBLIC
			valid_last: Result [{XT_PARSE_CONSTANTS}.ID_system] = SYSTEM
		end

end
