note
	description: "[
		Read/write access to fields in `struct XML_Encoding' defined in `<xpact.h>'.
		
			typedef struct {
				int map[256];
				void *data;
				int (XMLCALL *convert) (void *data, const char *s);
				void (XMLCALL *release) (void *data);
			} XML_Encoding;

		Include File:
		 	contrib/xpact/include/xpact.h
	]"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-10-01 17:07:00 GMT (Friday 1st October 2026)"
	revision: "1"

class
	XT_C_ENCODING_STRUCT

inherit
	EL_C_API

feature {NONE} -- Access

	frozen c_map_code (ptr: POINTER; i: INTEGER): INTEGER
		require
			encoding_attached: is_attached (ptr)
			valid_index: 0 <= i and i <= 0xFF
		external
			"C inline use <xpact.h>"
		alias
			"((XML_Encoding*) $ptr)->map [(int)$i]"
		end

	frozen c_convert (ptr: POINTER): POINTER
		require
			encoding_attached: is_attached (ptr)
		external
			"C inline use <xpact.h>"
		alias
			"((XML_Encoding*) $ptr)->convert"
		end

	frozen c_bytes_to_unicode (ptr, character_ptr: POINTER): INTEGER
		-- convert character byte sequnce at address `character_ptr' to unicode value using
		-- the convert function of XML_Encoding struct at address `ptr'
		require
			encoding_attached: is_attached (ptr)
			convert_attached: is_attached (c_convert (ptr))
		external
			"C inline use <xpact.h>"
		alias
			"[
				XML_Encoding* enc = ((XML_Encoding*) $ptr);
				return enc->convert (enc->data, $character_ptr);
			]"
		end

	frozen c_release (ptr: POINTER): POINTER
		require
			encoding_attached: is_attached (ptr)
		external
			"C inline use <xpact.h>"
		alias
			"((XML_Encoding*) $ptr)->release"
		end

feature {NONE} -- Measurement

	frozen c_size_of_encoding_struct: INTEGER
			-- Size in bytes of one `XML_Parser' record
		external
			"C inline use <xpact.h>"
		alias
			"sizeof (XML_Encoding)"
		end

feature {NONE} -- Element change

	frozen c_set_map_code (ptr: POINTER; i, code: INTEGER)
		require
			encoding_attached: is_attached (ptr)
			valid_index: 0 <= i and i <= 0xFF
		external
			"C inline use <xpact.h>"
		alias
			"((XML_Encoding*) $ptr)->map [(int)$i] = (int)$code;"
		ensure
			map_code_set: code = c_map_code (ptr, i)
		end

feature {NONE} -- Disposal

	frozen c_release_data (ptr: POINTER)
		require
			encoding_attached: is_attached (ptr)
		external
			"C inline use <xpact.h>"
		alias
			"[
				XML_Encoding* enc = (XML_Encoding*) $ptr;
				if (enc->release) {
					enc->release (enc->data);
					enc->release = NULL;
				}
				enc->data = NULL;
			]"
		end

end
