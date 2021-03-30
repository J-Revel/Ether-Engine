package render

Glyph :: struct
{
	size: [2]int,
	h_bearing: [2]int,
	h_adance: int,
	v_bearing: [2]int,
	v_advance: int
}

Font_Atlas :: struct
{
	texture_ids: []u32,
	glyphs: []rune,
}
