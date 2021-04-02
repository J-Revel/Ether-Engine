package render

import "core:log"
import "../../libs/freetype"
import gl "shared:odin-gl"


lib: freetype.Library;

init_font_render :: proc()
{
	freetype.init(&lib);
}

load_font :: proc(path: string, size: int, allocator := context.allocator) -> (font: Font, ok: bool)
{
	error := freetype.new_face(lib, path, 0, &font.face);
	if error != .OK
	{
		log.error("Font load error", error);
		return font, false;
	}
	freetype.set_pixel_sizes(font.face, 0, u32(size));
	return font, true;
}

load_single_glyph :: proc(using font: Font, character: rune) -> (glyph: Glyph, texture_id: u32, ok: bool)
{
	log.info(u32(character));
	error := freetype.load_char(font.face, u32(character), freetype.LOAD_RENDER);
	if error != .OK do return {}, 0, false;
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	glyph.size = [2]int {
		int(face.glyph.bitmap.width),
		int(face.glyph.bitmap.rows),
	};
	bitmap := &face.glyph.bitmap;
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		i32(glyph.size.x), i32(glyph.size.y),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		face.glyph.bitmap.buffer
	);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	gl.BindTexture(gl.TEXTURE_2D, 0);

	glyph = Glyph{
		size = [2]int{int(bitmap.width), int(bitmap.rows)},
		bearing = [2]int{int(face.glyph.bitmap_left), int(face.glyph.bitmap_top)},
		advance = [2]int{int(face.glyph.advance.x), int(face.glyph.advance.y)},
		uv_min = [2]f32{0, 0},
		uv_max = [2]f32{1, 1},
	};
	return glyph, texture_id, true;
}
