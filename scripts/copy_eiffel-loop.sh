

DEST=$PWD/contrib/Eiffel-Loop

EIFFEL_LOOP=$EIFFEL/library/Eiffel-Loop

names=(el_allocated_c_object el_c_object \
	el_string_h_c_api el_c_api el_eiffel_c_api el_zlib_crc_32_api \
	el_crc_32_digest el_crc_32_constants el_traceable_crc_32_digest \ 
	el_expanded_routines el_routines el_memory_routines el_typed_pointer_routines_i \
	el_integer_math_i el_integer_math el_typed_pointer_routines \
	el_ntfs_file_info el_character_8_buffer el_managed_c_string_8 el_any_shared \
	el_interval_constants el_interval_routines_i el_interval_routines)
	
args=()
for n in "${names[@]}"; do
	args+=(-o -name "$n.e")
done
pushd .

cd $EIFFEL_LOOP/library

file_list=$(find . \( "${args[@]:1}" \))

while IFS= read -r f; do
	mkdir -p "$DEST/$(dirname "$f")"
	cp -u "$f" "$DEST/$f"
done <<< "$file_list"

popd

