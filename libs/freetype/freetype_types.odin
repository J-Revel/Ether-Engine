package freetype

import "core:c"

Long  :: c.long;
ULong :: c.ulong;

Error :: distinct c.int;

F26Dot6 :: Long;

Handle :: struct{rawptr};

Library       :: distinct Handle;
CharMap       :: ^CharMapRec;
Size          :: distinct Handle;
Face          :: ^FaceRec;
GlyphSlot     :: ^GlyphSlotRec;
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
