package render

import "../../libs/freetype"

Glyph :: struct
{
	size: [2]int,
	bearing: [2]int,
	advance: int,
	uv_min: [2]f32,
	uv_max: [2]f32,
}

Font :: struct
{
	face: freetype.Face,
	texture_id: u32,
}

lib: freetype.Library;

init_font_render :: proc()
{
	freetype.init(&lib);
}

load_font :: proc(path: string, size: int, allocator := context.allocator) -> (font: Font, ok: bool)
{
	error := freetype.new_face(lib, path, 0, &font.face);
	if error > 0 do return font, false;
	freetype.set_pixel_sizes(font.face, 0, 16);
	test_glyph_index := freetype.get_char_index(font.face, 'a');
	error = freetype.load_glyph(font.face, test_glyph_index, freetype.LOAD_DEFAULT);
	if error > 0 do return font, false;
	error = freetype.render_glyph(font.face.glyph, freetype.RENDER_MODE_NORMAL);
	if error > 0 do return font, false;
	return font, true;
}

load_single_glyph :: proc(using font: Font) -> (glyph: Glyph, texture_id: uint)
{
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	texture_id: uint;
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	glyph.size = [2]int {
		face.glyph.bitmap.width,
		face.glyph.bitmap.rows,
	};
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		glyph.size.x, glyph.size.y,
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		face.glyph.bitmap.buffer
	);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAX_FILTER, gl.LINEAR);

	return glyph, texture_id;
}
