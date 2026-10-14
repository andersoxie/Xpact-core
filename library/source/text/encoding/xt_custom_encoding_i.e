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

	date: "2026-10-01 17:40:00 GMT (Friday 1st October 2026)"
	revision: "1"

deferred class
	XT_CUSTOM_ENCODING_I

inherit
	EL_ALLOCATED_C_OBJECT
		redefine
			dispose
		end

	XT_C_ENCODING_STRUCT
		rename
			c_size_of_encoding_struct as c_size_of
		undefine
			copy, is_equal
		end

feature {NONE} -- Initialization

	make
		do
			make_default
			fill_codes
		end

feature -- Element change

	fill_codes
		do
			fill_identity; fill_not_identity
		ensure
			valid_encoding: is_valid
		end

feature -- Status query

	has_converter: BOOLEAN
		do
			Result := is_attached (c_convert (self_ptr))
		end

	is_valid: BOOLEAN
		-- `True' if all map codes are valid
		local
			i: INTEGER
		do
			Result := True
			from i := 0 until i > 0xFF or not Result loop
				Result := is_valid_entry (i, c_map_code (self_ptr, i))
				i := i + 1
			end
		end

feature {NONE} -- Disposal

	dispose
		do
			c_release_data (self_ptr)
			Precursor
		end

feature {NONE} -- Implementation

	fill_not_identity
		deferred
		end

	fill_identity
		-- fill table so that index and code are identical
		-- (This works well for the ISO-8859-X/Windows-X family. Multi-byte codecs will
		-- overwrite large ranges with negative markers)
		local
			i: INTEGER
		do
			from i := 0 until i > 0xFF loop
				c_set_map_code (self_ptr, i, i)
				i := i + 1
			end
		end

	is_valid_entry (i, code: INTEGER): BOOLEAN
			-- `True' if map entry `code' at byte index `i' would be accepted by `XmlInitUnknownEncoding'
		do
			if code = -1 then
				Result := True
			elseif code < 0 then
				Result := code >= -4 and has_converter
			elseif code < 0x80 then
				Result := is_xml_significant (code) implies code = i
			else
				Result := code <= 0xFFFF
			end
		end

	is_xml_significant (code: INTEGER): BOOLEAN
		-- `True' if ASCII character `code' plays a role in XML syntax
		-- (whitespace, markup delimiter or name character). In an unknown-encoding
		-- map such a character must be decoded only from its own byte value: byte `i'
		-- must map to `i', and no other byte may map to it.
		-- (see libexpat `XmlInitUnknownEncoding'). Exempt are characters with
		-- byte type BT_NONXML or BT_OTHER in `asciitab.h'.
		require
			ascii_range: 0 <= code and code < 0x80
		do
			inspect code when 0 .. 8, 11, 12, 14 .. 31, 127 then
				-- BT_NONXML: control characters not allowed in XML
				-- (tab, LF and CR are excluded)

			else
				inspect code.to_character_8
					when '$', '@', '\', '^', '`', '{', '}', '~' then
						-- BT_OTHER: printable but no syntactic role

				else
					Result := True
				end
			end
		end

end
