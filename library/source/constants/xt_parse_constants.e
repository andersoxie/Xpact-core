note
	description: "Constants ported from expat.h and xmlparse.c (libexpat 2.x)"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-06-20 8:37:26 GMT (Saturday 20th June 2026)"
	revision: "1"

class XT_PARSE_CONSTANTS

feature {NONE} -- Parsing states (XML_Parsing enum)

	Parsing_states: ARRAY [INTEGER]
		once
			Result := <<
				State_check_encoding,
				State_initialized,
				State_parsing,
				State_finished,
				State_suspended
			>>
		end

	State_check_encoding: INTEGER = 0
	State_initialized: INTEGER = 1
	State_parsing: INTEGER = 2
	State_finished: INTEGER = 3
	State_suspended: INTEGER = 4

feature {NONE} -- Parsing states (XT_DECLARATION_PARTS_LIST)

	State_building: INTEGER = 1
	State_extending: INTEGER = 2
	State_external_id: INTEGER = 3 -- setting external (PUBLIC/SYSTEM) ID

feature {NONE} -- Parse status (XML_Status enum)

	Status_error: INTEGER = 0
	Status_ok: INTEGER = 1
	Status_suspended: INTEGER = 2

	Status_range: INTEGER_INTERVAL
		once
			Result := Status_error |..| Status_suspended
		end

	Status_names: STRING = "[
		Error
		OK
		Suspended
	]"

feature {NONE} -- enum XML_ParamEntityParsing

	PE_parsing_never: INTEGER = 0
	PE_parsing_unless_standalone: INTEGER = 1
	PE_parsing_always: INTEGER = 2

	Valid_parameter_entity_parsing_status: INTEGER_INTERVAL
		once
			Result := PE_parsing_never |..| PE_parsing_always
		end

feature {XT_DTD_KEYWORDS} -- Declaration types

	Valid_declaration_types: INTEGER_INTERVAL
		once
			Result := DOCTYPE_ |..| Parameter_entity
		end

	DOCTYPE_: INTEGER = 1

	ATTLIST_: INTEGER = 2

	ELEMENT_: INTEGER = 3

	ENTITY_: INTEGER = 4

	NOTATION_: INTEGER = 5

	Parameter_entity: INTEGER = 6

feature {XT_DTD_KEYWORDS} -- External ID types

	ID_public: INTEGER = 1

	ID_system: INTEGER = 2

feature {NONE} -- Entity expansion accounting

	Default_exponential_expansion_threshold: NATURAL_64 = 0x800000
		-- number of bytes processed after which checks for runaway expansion should be performed
		-- 10^9 LOL attack

	Default_max_expansion_proportion: REAL = 100.0
		-- 10^9 LOL attack

	Source_content: NATURAL_8 = 0

	Source_expansion: NATURAL_8 = 1
		-- entity expansion

	Source_expansion_with_checks: NATURAL_8 = 2
		-- entity expansion and instruction to test if `max_expansion_proportion' exceeded

end
