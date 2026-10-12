note
	description: "[
		Table of default values for attributes looked up by element name
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"
	date: "2026-09-18 16:01:00 GMT (Friday 18th September 2026)"
	revision: "1"

class
	XT_DEFAULT_ATTRIBUTE_VALUE_TABLE

inherit
	HASH_TABLE [SPECIAL [XT_DEFAULT_ATTRIBUTE_VALUE], STRING]
		rename
			make as make_sized,
			item_for_iteration as item_area,
			key_for_iteration as item_tag_name
		redefine
			same_keys
		end

	XT_NAMING_MODE_CONSTANTS
		undefine
			copy, is_equal
		end

	XT_STRING_CONSTANTS
		undefine
			copy, is_equal
		end

create
	make, make_sized

feature {NONE} -- Initialization

	make (default_value_table: HASH_TABLE [ARRAYED_LIST [STRING], STRING]; naming_mode: INTEGER)
		require
			even_number_of_name_value_pairs:
				across default_value_table as name_value_list all
					name_value_list.count.integer_remainder (2) = 0
				end
		local
			attribute_array: SPECIAL [XT_DEFAULT_ATTRIBUTE_VALUE]; i, colon_index: INTEGER
			default_value: XT_DEFAULT_ATTRIBUTE_VALUE
		do
			make_sized (default_value_table.count)
			if attached default_value_table as table then
				from table.start until table.after loop
					if attached table.item_for_iteration as name_value_list then
						create attribute_array.make_empty (name_value_list.count // 2)
						from i := 1 until i > name_value_list.count loop
							if name_value_list.valid_index (i + 1) then
								create default_value.make_from_i_th (name_value_list, i)
								inspect naming_mode when NM_uri_SEP_localname, NM_uri_SEP_localname_SEP_prefix then
								-- remove attributes xmlns and xml:* for xmlns URI mapping modes
									if attached default_value.name as name then
										colon_index := name.index_of (':', 1)
										if colon_index.to_boolean and then name.count >= 5 and then name.starts_with (Xml_lower) then
											do_nothing -- eg. xml:lang

										elseif name ~ xmlns then
											do_nothing
										else
											attribute_array.extend (default_value)
										end
									end
								else
									attribute_array.extend (default_value)
								end
							end
							i := i + 2
						end
						if attribute_array.count > 0 then
							extend (attribute_array, table.key_for_iteration)
						end
					end
					table.forth
				end
			end
		end

feature {NONE} -- Implementation

	same_keys (a_search_key, a_key: STRING): BOOLEAN
		do
			Result := a_search_key.same_string (a_key)
		end

end
