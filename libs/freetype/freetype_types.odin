package freetype

import "core:c"

Long  :: c.long;
ULong :: c.ulong;

Error_Code :: distinct c.int;

F26Dot6 :: Long;

Handle :: struct{rawptr};

Library       :: distinct Handle;
CharMap       :: ^CharMapRec;
Face          :: ^FaceRec;
GlyphSlot     :: ^GlyphSlotRec;
Size		  :: ^SizeRec;

Size_Internal :: distinct Handle;
Face_Internal :: distinct Handle;
Driver        :: distinct Handle;
Memory        :: distinct Handle;
Stream        :: distinct Handle;
SubGlyph      :: distinct Handle;
Slot_Internal :: distinct Handle;

Generic_Finalizer :: #type proc "c" (object: rawptr);
Generic :: struct {
	data: rawptr,
	finalizer: Generic_Finalizer,
}

Pos :: distinct Long;
Fixed :: distinct Long;

Vector :: struct{
	x, y: Pos,
};

Matrix :: struct{
	xx, xy: Fixed,
	yx, yy: Fixed,
};

Encoding :: enum u32 {
	NONE = 0,

	MS_SYMBOL = 's'<<24 | 'y'<<16 | 'm'<<8 | 'b',
	UNICODE   = 'u'<<24 | 'n'<<16 | 'i'<<8 | 'c',

	SJIS =    's'<<24 | 'j'<<16 | 'i'<<8 | 's',
	PRC =     'g'<<24 | 'b'<<16 | ' '<<8 | ' ',
	BIG5 =    'b'<<24 | 'i'<<16 | 'g'<<8 | '5',
	WANSUNG = 'w'<<24 | 'a'<<16 | 'n'<<8 | 's',
	JOHAB =   'j'<<24 | 'o'<<16 | 'h'<<8 | 'a',

	// for backward compatibility
	GB2312     = PRC,
	MS_SJIS    = SJIS,
	MS_GB2312  = PRC,
	MS_BIG5    = BIG5,
	MS_WANSUNG = WANSUNG,
	MS_JOHAB   = JOHAB,

	ADOBE_STANDARD = 'A'<<24 | 'D'<<16 | 'O'<<8 | 'B',
	ADOBE_EXPERT   = 'A'<<24 | 'D'<<16 | 'B'<<8 | 'E',
	ADOBE_CUSTOM   = 'A'<<24 | 'D'<<16 | 'B'<<8 | 'C',
	ADOBE_LATIN_1  = 'l'<<24 | 'a'<<16 | 't'<<8 | '1',

	OLD_LATIN_2 = 'l'<<24 | 'a'<<16 | 't'<<8 | '2',

	APPLE_ROMAN = 'a'<<24 | 'r'<<16 | 'm'<<8 | 'n',
};

Glyph_Format :: enum c.int {
	NONE      = 0,

	COMPOSITE = 'c'<<24 | 'o'<<16 | 'm'<<8 | 'p',
	BITMAP    = 'b'<<24 | 'i'<<16 | 't'<<8 | 's',
	OUTLINE   = 'o'<<24 | 'u'<<16 | 't'<<8 | 'l',
	PLOTTER   = 'p'<<24 | 'l'<<16 | 'o'<<8 | 't',
}

CharMapRec :: struct {
	face:        Face,
	encoding:    Encoding,
	platform_id: u16,
	encoding_id: u16,
}

Glyph_Metrics :: struct {
	width:        Pos,
	height:       Pos,

	horiBearingX: Pos,
	horiBearingY: Pos,
	horiAdvance:  Pos,

	vertBearingX: Pos,
	vertBearingY: Pos,
	vertAdvance:  Pos,
}

Size_Metrics :: struct
{
	x_ppem: u16,
	y_ppem: u16,

	x_scale: Fixed,
	y_scale: Fixed,

	ascender: Pos,
	descender: Pos,
	height: Pos,
	max_advance: Pos,
}

SizeRec :: struct
{
	face: Face,
	generic: Generic,
	metrics: Size_Metrics,
	internal: Size_Internal,
}


GlyphSlotRec :: struct {
	library:  Library,
	face:     Face,
	next:     GlyphSlot,
	reserved: u32, // retained for binary compatibility
	generic:  Generic,

	metrics:           Glyph_Metrics,
	linearHoriAdvance: Fixed,
	linearVertAdvance: Fixed,
	advance:           Vector,

	format: Glyph_Format,

	bitmap:      Bitmap,
	bitmap_left: c.int,
	bitmap_top:  c.int,

	outline: Outline,

	num_subglyphs: u32,
	subglyphs:     SubGlyph,

	control_data: rawptr,
	control_len:  Long,

	lsb_delta: Pos,
	rsb_delta: Pos,

	other: rawptr,

	internal: Slot_Internal,
}

Outline :: struct {
	n_contours: i16,     // number of contours in glyph
	n_points:   i16,     // number of points in the glyph

	points:     ^Vector, // the outline's points
	tags:       cstring, // the points flags
	contours:   ^i16,    // the contour end points

	flags:      i32,     // outline masks
}

Bitmap :: struct {
	rows:         u32,
	width:        u32,
	pitch:        i32,
	buffer:       ^byte,
	num_grays:    u16,
	pixel_mode:   u8,
	palette_mode: u8,
	palette:      rawptr,
}

Bitmap_Size :: struct {
	height: i16,
	width:  i16,

	size:   Pos,

	x_ppem: Pos,
	y_ppem: Pos,
};

BBox :: struct {
	xMin, yMin: Pos,
	xMax, yMax: Pos,
}

ListNode :: distinct rawptr;

ListRec :: struct {
	head: ListNode,
	tail: ListNode,
}


FaceFlag :: enum Long {
	SCALABLE          =  0,
	FIXED_SIZES       =  1,
	FIXED_WIDTH       =  2,
	SFNT              =  3,
	HORIZONTAL        =  4,
	VERTICAL          =  5,
	KERNING           =  6,
	FAST_GLYPHS       =  7,
	MULTIPLE_MASTERS  =  8,
	GLYPH_NAMES       =  9,
	EXTERNAL_STREAM   = 10,
	HINTER            = 11,
	CID_KEYED         = 12,
	TRICKY            = 13,
	COLOR             = 14,
	VARIATION         = 15,
}

FaceRec :: struct {
	num_faces:           Long,
	face_index:          Long,

	face_flags:          bit_set[FaceFlag; Long],
	style_flags:         Long,

	num_glyphs:          Long,

	family_name:         cstring,
	style_name:          cstring,

	num_fixed_sizes:     c.int,
	available_sizes:     Bitmap_Size,

	num_charmaps:        c.int,
	charmaps:            ^CharMap,

	generic:             Generic,

	// The following member variables (down to `underline_thickness')
	// are only relevant to scalable outlines; cf. @FT_Bitmap_Size
	// for bitmap fonts.
	bbox:                BBox,

	units_per_EM:        u16,
	ascender:            i16,
	descender:           i16,
	height:              i16,

	max_advance_width:   i16,
	max_advance_height:  i16,

	underline_position:  i16,
	underline_thickness: i16,

	glyph:               GlyphSlot,
	size:                Size,
	charmap:             CharMap,

	driver:              Driver,
	memory:              Memory,
	stream:              Stream,

	sizes_list:          ListRec,

	autohint:            Generic, // face-specific auto-hinter data
	extensions:          rawptr,  // unused

	internal:            Face_Internal,
}

Error :: enum
{
	OK 						       = 0x00,
	CANNOT_OPEN_RESOURCE 	       = 0x01,
	UNKNOWN_FILE_FORMAT   	       = 0x02,
	INVALID_FILE_FORMAT 	       = 0x03,
	INVALID_VERSION			       = 0x04,
	LOWER_MODULE_VERSION	       = 0x05,
	INVALID_ARGUMENT	           = 0x06,
	UNIMPLEMENTED_FEATURE	       = 0x07,
	INVALID_TABLE			       = 0x08,
	INVALID_OFFSET			       = 0x09,
	ARRAY_TOO_LARGE			       = 0x0A,
	MISSING_MODULE				   = 0x0B,
	MISSING_PROPERTY		       = 0x0C,
	INVALID_GLYPH_INDEX			   = 0x10,
	INVALID_CHARACTER_CODE	       = 0x11,
	INVALID_GLYPH_FORMAT           = 0x12,
	CANNOT_RENDER_GLYPH            = 0x13,
	INVALID_OUTLINE                = 0x14,
	INVALID_COMPOSITE              = 0x15,
	TOO_MANY_HINTS                 = 0x16,
	INVALID_PIXEL_SIZE             = 0x17,
	INVALID_HANDLE                 = 0x20,
	INVALID_LIBRARY_HANDLE         = 0x21,
	INVALID_DRIVER_HANDLE          = 0x22,
	INVALID_FACE_HANDLE            = 0x23,
	INVALID_SIZE_HANDLE            = 0x24,
	INVALID_SLOT_HANDLE            = 0x25,
	INVALID_CHARMAP_HANDLE         = 0x26,
	INVALID_CACHE_HANDLE           = 0x27,
	INVALID_STREAM_HANDLE          = 0x28,
	TOO_MANY_DRIVERS               = 0x30,
	TOO_MANY_EXTENSIONS            = 0x31,
	OUT_OF_MEMORY                  = 0x40,
	UNLISTED_OBJECT                = 0x41,
	CANNOT_OPEN_STREAM             = 0x51,
	INVALID_STREAM_SEEK            = 0x52,
	INVALID_STREAM_SKIP            = 0x53,
	INVALID_STREAM_READ            = 0x54,
	INVALID_STREAM_OPERATION       = 0x55,
	INVALID_FRAME_OPERATION        = 0x56,
	NESTED_FRAME_ACCESS            = 0x57,
	INVALID_FRAME_READ             = 0x58,
	RASTER_UNINITIALIZED           = 0x60,
	RASTER_CORRUPTED               = 0x61,
	RASTER_OVERFLOW                = 0x62,
	RASTER_NEGATIVE_HEIGHT         = 0x63,
	TOO_MANY_CACHES                = 0x70,
	INVALID_OPCODE                 = 0x80,
	TOO_FEW_ARGUMENTS              = 0x81,
	STACK_OVERFLOW                 = 0x82,
	CODE_OVERFLOW                  = 0x83,
	BAD_ARGUMENT                   = 0x84,
	DIVIDE_BY_ZERO                 = 0x85,
	INVALID_REFERENCE              = 0x86,
	DEBUG_OPCODE                   = 0x87,
	ENDF_IN_EXEC_STREAM            = 0x88,
	NESTED_DEFS                    = 0x89,
	INVALID_CODERANGE              = 0x8A,
	EXECUTION_TOO_LONG             = 0x8B,
	TOO_MANY_FUNCTION_DEFS         = 0x8C,
	TOO_MANY_INSTRUCTION_DEFS      = 0x8D,
	TABLE_MISSING                  = 0x8E,
	HORIZ_HEADER_MISSING           = 0x8F,
	LOCATIONS_MISSING              = 0x90,
	NAME_TABLE_MISSING             = 0x91,
	CMAP_TABLE_MISSING             = 0x92,
	HMTX_TABLE_MISSING             = 0x93,
	POST_TABLE_MISSING             = 0x94,
	INVALID_HORIZ_METRICS          = 0x95,
	INVALID_CHARMAP_FORMAT         = 0x96,
	INVALID_PPEM                   = 0x97,
	INVALID_VERT_METRICS           = 0x98,
	COULD_NOT_FIND_CONTEXT         = 0x99,
	INVALID_POST_TABLE_FORMAT      = 0x9A,
	INVALID_POST_TABLE             = 0x9B,
	DEF_IN_GLYF_BYTECODE           = 0x9C,
	MISSING_BITMAP                 = 0x9D,
	SYNTAX_ERROR                   = 0xA0,
	STACK_UNDERFLOW                = 0xA1,
	IGNORE                         = 0xA2,
	NO_UNICODE_GLYPH_NAME          = 0xA3,
	GLYPH_TOO_BIG                  = 0xA4,
	MISSING_STARTFONT_FIELD        = 0xB0,
	MISSING_FONT_FIELD             = 0xB1,
	MISSING_SIZE_FIELD             = 0xB2,
	MISSING_FONTBOUNDINGBOX_FIELD  = 0xB3,
	MISSING_CHARS_FIELD            = 0xB4,
	MISSING_STARTCHAR_FIELD        = 0xB5,
	MISSING_ENCODING_FIELD         = 0xB6,
	MISSING_BBX_FIELD              = 0xB7,
	BBX_TOO_BIG                    = 0xB8,
	CORRUPTED_FONT_HEADER          = 0xB9,
	CORRUPTED_FONT_GLYPHS          = 0xBA,
}
