package freetype
import "core:strings"

init :: proc(library: ^Library) -> Error { return Init_FreeType(library); }
done :: proc(library: Library) -> Error { return Done_FreeType(library); }


new_face :: #force_inline proc(library: Library, filepathname: string, face_index: Long, aface: ^Face) -> Error 
{
	return New_Face(library, strings.clone_to_cstring(filepathname, context.temp_allocator), face_index, aface);
}

new_memory_face :: #force_inline proc(library: Library, file_base: ^byte, file_size: Long, face_index: Long, aface: ^Face) -> Error
{
	return New_Memory_Face(library, file_base, file_size, face_index, aface);
}

free_face :: #force_inline proc(face: Face) -> Error
{
	return Done_Face(face);
}


set_char_size :: #force_inline proc(face: Face, char_width, char_height: i32, horz_resolution, vert_resolution: u32) -> Error
{
	return Set_Char_Size(face, char_width, char_height, horz_resolution, vert_resolution);
}

set_pixel_sizes :: #force_inline proc(face: Face, pixel_width, pixel_height: u32) -> Error
{
	return Set_Pixel_Sizes(face, pixel_width, pixel_height);
}

get_first_char :: #force_inline proc(face: Face, index: ^u32) -> u32
{
	return Get_First_Char(face, index);
}

get_next_char :: #force_inline proc(face: Face, character: u32, index: ^u32) -> u32
{
	return Get_Next_Char(face, character, index);
}

get_char_index :: #force_inline proc(face: Face, character: rune) -> u32
{
	return Get_Char_Index(face, ULong(character));
}


get_kerning :: #force_inline proc(face: Face, left_glyph, right_glyph: u32, kern_mode: u32, akerning: ^Vector) -> Error
{
	return Get_Kerning(face, left_glyph, right_glyph, kern_mode, akerning);
}

load_char :: #force_inline proc(face: Face, char_code: u32, load_flags: i32) -> Error
{
	return Load_Char(face, char_code, load_flags);
}

load_glyph :: #force_inline proc(face: Face, glyph_index: u32, load_flags: i32) -> Error
{
	return Load_Glyph(face, glyph_index, load_flags);
}

select_charmap :: #force_inline proc(face: Face, encoding: Encoding) -> Error
{
	return Select_Charmap(face, encoding);
}

set_transform :: #force_inline proc(face: Face, matrix: ^Matrix, delta: ^Vector)
{
	Set_Transform(face, matrix, delta);
}


load_sfnt_table	:: #force_inline proc(face: Face, tag: ULong, offset: Long, buffer: ^byte, length: ^ULong) -> Error
{
	return Load_Sfnt_Table(face, tag, offset, buffer, length);
}

