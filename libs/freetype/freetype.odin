package freetype

import "core:os"
import "core:c"

when os.OS == "windows" {
	foreign import freetype {
		"freetype.lib",
		// "system:legacy_stdio_definitions.lib",
	}
}


@(link_prefix="FT_", default_calling_convention="c")
foreign freetype {
	Init_FreeType   :: proc(library: ^Library) -> Error ---
	Done_FreeType   :: proc(library: Library) -> Error ---

	New_Face        :: proc(library: Library, filepathname: cstring, face_index: Long, aface: ^Face) -> Error ---
	New_Memory_Face :: proc(library: Library, file_base: ^byte, file_size: Long, face_index: Long, aface: ^Face) -> Error ---
	Done_Face       :: proc(face: Face) -> Error ---

	Set_Char_Size   :: proc(face: Face, char_width, char_height: F26Dot6, horz_resolution, vert_resolution: u32) -> Error ---
	Set_Pixel_Sizes :: proc(face: Face, pixel_width, pixel_height: u32) -> Error ---

	Get_First_Char  :: proc(face: Face, index: ^u32) -> c.ulong ---;
	Get_Next_Char   :: proc(face: Face, character: c.ulong, index: ^u32) -> c.ulong ---;
	Get_Char_Index  :: proc(face: Face, charcode: ULong) -> u32 ---

	Get_Kerning     :: proc(face: Face, left_glyph, right_glyph: u32, kern_mode: u32, akerning: ^Vector) -> Error ---

	Load_Char       :: proc(face: Face, char_code: u32, load_flags: i32) -> Error ---
	Load_Glyph      :: proc(face: Face, glyph_index: u32, load_flags: i32) -> Error ---

	Select_Charmap  :: proc(face: Face, encoding: Encoding) -> Error ---

	Set_Transform   :: proc(face: Face, matrix: ^Matrix, delta: ^Vector) ---

	Load_Sfnt_Table :: proc(face: Face, tag: ULong, offset: Long, buffer: ^byte, length: ^ULong) -> Error ---
}

HAS_KERNING :: #force_inline proc(face: Face) -> bool {
	return FaceFlag.KERNING in face.face_flags;
}



LOAD_DEFAULT                     :: 0;
LOAD_NO_SCALE                    :: 1 << 0;
LOAD_NO_HINTING                  :: 1 << 1;
LOAD_RENDER                      :: 1 << 2;
LOAD_NO_BITMAP                   :: 1 << 3;
LOAD_VERTICAL_LAYOUT             :: 1 << 4;
LOAD_FORCE_AUTOHINT              :: 1 << 5;
LOAD_CROP_BITMAP                 :: 1 << 6;
LOAD_PEDANTIC                    :: 1 << 7;
LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH :: 1 << 9;
LOAD_NO_RECURSE                  :: 1 << 10;
LOAD_IGNORE_TRANSFORM            :: 1 << 11;
LOAD_MONOCHROME                  :: 1 << 12;
LOAD_LINEAR_DESIGN               :: 1 << 13;
LOAD_NO_AUTOHINT                 :: 1 << 15;
// Bits 16-19 are used by `FT_LOAD_TARGET_'
LOAD_COLOR                       :: 1 << 20;
LOAD_COMPUTE_METRICS             :: 1 << 21;
LOAD_BITMAP_METRICS_ONLY         :: 1 << 22;


// used internally only by certain font drivers
LOAD_ADVANCE_ONLY                :: 1 << 8;
LOAD_SBITS_ONLY                  :: 1 << 14;


KERNING_DEFAULT  :: 0;
KERNING_UNFITTED :: 1;
KERNING_UNSCALED :: 2;

TTAG_GSUB :: 0x47535542;


pos6_to_f32 :: proc(p: Pos) -> f32 {
	return f32(p >> 6) + f32(p & 0b111111)/64;
}
pos6_to_i16 :: proc(p: Pos) -> i16 {
	return i16(p >> 6);
}


