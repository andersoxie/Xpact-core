note
	description: "[
		A interface for XML_Encoding struct to decode a Japanese language test file encoded using the
		legacy Shift_JIS encoding. This partial implementation only works with the intended test subject:
		
			tools/data/encoding-Shift_JIS_subset.xml
			
		Source code:
		
			C-tools/shift_jis_subset/src/shift_jis_subset.c
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-10-13 15:57:00 GMT (Tuesday 13th October 2026)"
	revision: "1"

class
	XT_SHIFT_JIS_TEST_ENCODING

inherit
	XT_CUSTOM_ENCODING
		redefine
			fill_codes
		end

create
	make

feature -- Element change

	fill_codes
		do
			if c_fill_shift_jis_subset (self_ptr) then
			end
		end

feature {NONE} -- C External	

	frozen c_fill_shift_jis_subset (ptr: POINTER): BOOLEAN
		external
			"C inline use <shift_jis_subset.h>"
		alias
			"shift_jis_subset_fill_encoding ((void*) $ptr)"
		end
end
