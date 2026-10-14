note
	description: "[
		A fast lookup cache of name strings that will enable fast C strlen in library client
		due to L1/L2 caching on CPU.
	]"
	notes: "See end of class"

	author: "Finnian Reilly`"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-06-20 6:31:14 GMT (Saturday 20th June 2026)"
	revision: "1"

class
	XT_NAME_CACHE

inherit
	XT_STRING_8_ROUTINES_I
		rename
			to_list as new_list
		export
			{ANY} valid_substring_intervals
			{NONE} all
		end

create
	make

feature {NONE} -- Initialization

	make
		do
			create bucket_area.make_filled (Default_bucket, Size)
			create entity_context_buffer.make_empty
		end

feature -- Measurement

	average_bucket_item_count: INTEGER
		local
			count, item_count, i, i_final: INTEGER
		do
			if attached bucket_area as l_area then
				from i := 0; i_final := l_area.count - 1 until i = i_final loop
					if attached l_area [i] as bucket and then bucket /= Default_bucket then
						count := count + 1
						item_count := item_count + bucket.count
					end
					i := i + 1
				end
			end
			Result := (item_count / count).rounded
		end

	buckets_used_count: INTEGER
		local
			i, i_final: INTEGER
		do
			if attached bucket_area as l_area then
				from i := 0; i_final := l_area.count - 1 until i = i_final loop
					if attached l_area [i] as bucket and then bucket /= Default_bucket then
						Result := Result + 1
					end
					i := i + 1
				end
			end
		end

feature -- Access

	bucket_distribution_gt_1: XT_NAME_OCCURRENCE_COUNT_TABLE
		do
			create Result.make (50)
			across bucket_area as bucket loop
				if bucket.count > 1 then
					Result.put (substitute (Stats_template, << bucket.count.out >>))
				end
			end
		end

	default_name: like Default_bucket.item
		do
			Result := Default_bucket [0]
		end

	entity_context (entity: XT_ENTITY_NAME): STRING
		do
			Result := entity_context_buffer
			Result.wipe_out
			if entity.count >= 3 then
				Result.append_substring (entity, 2, entity.count - 1)
			end
			null_terminate (Result)
		ensure
			null_terminated: null_terminated (Result)
		end

	item, attribute_item (buffer: SPECIAL [CHARACTER]; start_index, end_index, colon_index: INTEGER): like default_name
		-- UTF-8 encoded name
		require
			valid_range: start_index <= end_index
			not_empty: not is_empty
			valid_colon_index: colon_index > 0 implies buffer [colon_index] = ':'
		local
			i, j, bucket_count: INTEGER; bucket: like bucket_area.item
			found: BOOLEAN;
		do
			Result := default_name
			inspect colon_index when 0 then
				i := bucket_index (buffer, start_index, end_index)
			else
			-- proveably better distribution if you use character after ':'
				i := bucket_index (buffer, colon_index + 1, end_index)
			end
			bucket := bucket_area [i]
			if bucket = Default_bucket then
				create bucket.make_empty (5)
				bucket_area [i] := bucket
			else
			-- search for match
				bucket_count := bucket.count
				from j := 0 until j = bucket_count or found loop
					if same_name (buffer, start_index, end_index, colon_index, bucket [j]) then
						Result := bucket [j]
						found := True
					else
						j := j + 1
					end
				end
			end
			if not found then
				Result := new_name (buffer, start_index, end_index, colon_index)
				if bucket.count + 1 > bucket.capacity then
					bucket := bucket.aliased_resized_area (bucket.capacity + bucket.capacity // 2)
					bucket_area [i] := bucket
				end
				bucket.extend (Result)
				debug ("name_cache")
				-- openxmlformats can have many similar tag names of the same length (See notes)
					check
						well_distributed_hash_indices: bucket.count <= 4 -- Tested mandarin-names-and-text.xsl
					end
				end
			end
		ensure
			found_or_created: Result /= default_name
			null_terminated: Result.area [Result.count] = '%U'
		end

	attribute_name (str: STRING): like default_name
		-- `attribute_item' from `str'
		do
			Result := attribute_item (str.area, 0, str.count - 1, 0)
		end

feature -- Conversion

	to_list: ARRAYED_LIST [like default_name]
		local
			i, i_final, j, j_final: INTEGER
		do
			create Result.make ((buckets_used_count * 1.05).rounded)
			if attached bucket_area as l_area then
				from i := 0; i_final := l_area.count - 1 until i = i_final loop
					if attached l_area [i] as bucket and then bucket /= Default_bucket then
						from j := 0; j_final := bucket.count - 1 until j = j_final loop
							Result.extend (bucket [j])
							j := j + 1
						end
					end
					i := i + 1
				end
			end
		end

feature -- Status query

	is_empty: BOOLEAN
			-- Is structure empty?
		do
			Result := bucket_area.count = 0
		end

feature -- Basic operations

	reset
		local
			i: INTEGER
		do
			if attached bucket_area as a then
				from i := 0 until i = Size loop
					if attached a [i] as bucket and then bucket /= Default_bucket then
						bucket.wipe_out
					end
					i := i + 1
				end
			end
		end

	put_status (output: IO_MEDIUM)
		do
			output.put_string ("NAME CACHING")
			output.put_new_line
			output.put_string ("Buckets used count: ")
			output.put_integer (buckets_used_count)
			output.put_new_line
			output.put_string ("Average hash bucket count: ")
			output.put_integer (average_bucket_item_count)
			output.put_new_line
			output.put_string ("Hash bucket counts greater than 1")
			output.put_string (":%N")
			if attached bucket_distribution_gt_1.sorted_occurrence_list (False) as sorted_list then
				if sorted_list.count = 0 then
					output.put_string ("None")
				else
					across sorted_list as bucket_count loop
						output.put_string ("   ")
						bucket_count.put_status (output)
					end
				end
			end
			output.put_new_line
		end

	transfer (
		buffer: SPECIAL [CHARACTER_8]; additions: SPECIAL [INTEGER]; colon_index: INTEGER
		attribute_list: XT_ATTRIBUTE_LIST; entity_list: ARRAYED_LIST [XT_ENTITY_NAME]
	): INTEGER
		-- add xmlns declaration
		require
			full_buffer: additions.count = 4
			valid_colon_index: colon_index.to_boolean implies additions [0] < colon_index and then colon_index <  additions [1]
			valid_intervals: valid_substring_intervals (additions)
			is_xmlns_declaration: attribute_list.is_xmlns_declaration (buffer, additions, colon_index)
		do
		-- redefined in `XT_URI_MAPPED_ATTRIBUTE_LIST'
		end

feature -- Event handler

	on_pop (element_context: XT_ELEMENT_CONTEXT; handler: XT_PARSE_EVENTS; parse_data: POINTER)
		-- notification after `element_context.pop' was called
		do
			-- redefined in `XT_URI_MAPPED_NAME_CACHE'
		end

	on_xmlns_declaration_end (
		buffer: SPECIAL [CHARACTER_8]; tag_name_lower, tag_name_upper: INTEGER
		parser: XT_XML_PARSER_BASE; attribute_list: XT_ATTRIBUTE_LIST
	)
		-- notification after reading list of attributes containing xmlns declaration
		do
			-- redefined in `XT_URI_MAPPED_NAME_CACHE'
		end

feature -- Contract support

	valid_tag_name_count (tag_name: like default_name; expected_count: INTEGER): BOOLEAN
		do
			Result := tag_name.count = expected_count
		end

feature {NONE} -- Implementation

	hash_index, bucket_index (buffer: SPECIAL [CHARACTER]; start_index, end_index: INTEGER): INTEGER
		-- very fast well distributed hash with only 3 components
		local
			first, last, count: NATURAL; i, utf_byte_count: INTEGER
		do
			count := (end_index - start_index + 1).to_natural_32
			inspect count
				when 1 then
					first := buffer [start_index].natural_32_code
					Result := size_remainder (first * Golden_ratio, first * Golden_ratio |>> 8)
				when 2 .. 4 then
					first := buffer [start_index].natural_32_code
					last := buffer [end_index].natural_32_code
					Result := size_remainder (first |<< 4, (last |<< 1).bit_xor (count))

			else
				first := buffer [start_index].natural_32_code
				if first > 0x7F then
					if first <= 0xDF then
						-- 110xxxxx 10xxxxxx
						utf_byte_count := 2

					elseif first <= 0xEF then
						-- 1110xxxx 10xxxxxx 10xxxxxx
						utf_byte_count := 3

					elseif first <= 0xF7 then
						-- first <= 1FFFFF - there are no higher code points
						-- 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
						utf_byte_count := 4
					end
					from i := 1 until i = utf_byte_count loop
						first := (first |<< 8) | buffer [start_index + i].natural_32_code
						i := i + 1
					end
				end
				last := buffer [end_index].natural_32_code
				Result := size_remainder (first |<< 4, (last |<< 1).bit_xor (count))
			end
		end

	name_area (name: like default_name): SPECIAL [CHARACTER]
		do
			Result := name.area
		end

	name_count (name: like default_name): INTEGER
		do
			Result := name.count
		end

	new_name (buffer: SPECIAL [CHARACTER]; start_index, end_index, colon_index: INTEGER): like default_name
			-- Buffer bytes [start_index .. end_index) as a STRING_8.
			-- UTF-8 bytes are copied as-is; correct on UTF-8 terminals.
		do
			Result := new_substring (buffer, start_index, end_index)
		end

	same_name (buffer: SPECIAL [CHARACTER]; start_index, end_index, colon_index: INTEGER; name: like default_name): BOOLEAN
		local
			i, count: INTEGER
		do
			count := end_index - start_index + 1
			if count = name_count (name) and then attached name_area (name) as l_area then
				inspect count when 1 .. 5 then
					Result := buffer.same_items (l_area, 0, start_index, count)
				else
					if buffer [start_index] = l_area [0] and then buffer [end_index] = l_area [count - 1]
						and then (colon_index > 0 implies l_area [colon_index - start_index] = ':')
					then
						from i := 1; Result := True until i = count loop
							if l_area [i] = buffer [start_index + i] then
								i := i + 1
							else
								i := count -- break
								Result := False
							end
						end
					end
				end
			end
		end

	size_remainder (a, b: NATURAL): INTEGER
		do
			Result := a.bit_xor (b).integer_remainder (Size.to_natural_32).to_integer_32
		ensure
			positive: Result >= 0
		end

feature {NONE} -- Internal attributes

	bucket_area: SPECIAL [like Default_bucket]
		-- array of buckets holding names with same hash value

	entity_context_buffer: STRING

feature {NONE} -- Constants

	Default_bucket: SPECIAL [STRING]
		once ("PROCESS")
			create Result.make_filled (create {like default_name}.make_empty, 1)
		end

	Golden_ratio: NATURAL = 2654435769

	Size: INTEGER = 607

	Stats_template: STRING = "has %S items"

invariant
	default_bucket_has_default_item: Default_bucket.count = 1

note
	notes: "[
		Largest XML vocabularies tend to only have 100 to 500 names.

		XHTML/HTML5 as XML, around 120 element types
		TEI (Text Encoding Initiative): a scholarly text markup standard with over 500 element types, widely used
		in digital humanities.
		DITA (Darwin Information Typing Architecture): technical documentation format with 200+ element types
		UBL (Universal Business Language): XML standard for business documents with hundreds of element types
		across many schemas
		HL7 FHIR XML:  healthcare data interchange with hundreds of resource types

		The maths for 512 buckets

		10 names across 512 buckets: average 0.02 per bucket, virtually every lookup hits an empty bucket immediately
		50 names across 512 buckets: average 0.1 per bucket, collisions extremely rare
		200 names across 512 buckets: average 0.4 per bucket, most buckets still empty or single entry
		500 names across 512 buckets: average 1.0 per bucket, linear search of 1-2 entries is essentially free

		At 512+ buckets long linear searchs happen rarely.For most vocabularies every bucket
		has 0, 1, or occasionally 2 entries. The Linear_search_count threshold of 10 becomes largely irrelevant
		because no bucket ever gets close to it. The memory cost is genuinely negligible

		**The Exception**

		Some openxmlformats can have many similar tag names of the same length which don't distribute well.
		For eg. eaLnBrk lvl1pPr lvl2pPr lvl3pPr lvl4pPr lvl5pPr lvl6pPr lvl7pPr lvl8pPr lvl9pPr notesSz
		all have length 7. These must be linearly searched.
	]"

end
