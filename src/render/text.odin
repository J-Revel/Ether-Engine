package render

import "core:log"
import "core:math/linalg"
import "core:fmt"

import gl "shared:odin-gl"

import "../../libs/freetype"

import "../container"
import "../util"

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
	};
	return glyph, texture_id, true;
}

init_font_atlas :: proc(texture_table: ^container.Table(Texture), atlas: ^Font_Atlas, texture_size := 2048)
{
	texture_id: u32;
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		i32(texture_size), i32(texture_size),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		nil,
	);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	gl.BindTexture(gl.TEXTURE_2D, 0);
	ok: bool;
	atlas.texture_handle, ok = container.table_add(texture_table, Texture{texture_id = texture_id, size = [2]int{texture_size, texture_size}});
	assert(ok);
	init_atlas(&atlas.pack_tree, [2]f32{f32(texture_size), f32(texture_size)});
	atlas.texture_size = [2]int{texture_size, texture_size};
}

load_glyph :: proc(using font_atlas: ^Font_Atlas, font: Font, character: rune, sprite_table: ^container.Table(Sprite)) -> (glyph: Glyph, ok: bool)
{
	error := freetype.load_char(font.face, u32(character), freetype.LOAD_RENDER);
	if error != .OK do return {}, false;
	glyph.size = [2]int {
		int(font.face.glyph.bitmap.width),
		int(font.face.glyph.bitmap.rows),
	};
	bitmap := &font.face.glyph.bitmap;

	glyph = Glyph{
		size = [2]int{int(bitmap.width), int(bitmap.rows)},
		bearing = [2]int{int(font.face.glyph.bitmap_left), int(font.face.glyph.bitmap_top)},
		advance = [2]int{int(font.face.glyph.advance.x), int(font.face.glyph.advance.y)},
	};
	allocated_rect, alloc_ok := allocate_rect(&font_atlas.pack_tree, [2]f32{f32(bitmap.width), f32(bitmap.rows)});
	assert(alloc_ok);
	uv_rect := util.Rect{allocated_rect.pos / linalg.to_f32(texture_size), allocated_rect.size / linalg.to_f32(texture_size)};
	add_ok: bool;
	sprite :=  Sprite {
		texture = font_atlas.texture_handle,
		id = fmt.aprint("char", character),
		data = {
			clip = uv_rect
		}
	};
	glyph.sprite, add_ok = container.table_add(sprite_table, sprite);
	log.info(add_ok, sprite);
	assert(add_ok);
	if alloc_ok
	{
		texture_data := container.handle_get(texture_handle);
		gl.BindTexture(gl.TEXTURE_2D, texture_data.texture_id);
		gl.TexSubImage2D(
			gl.TEXTURE_2D,
			0,
			i32(allocated_rect.pos.x),
			i32(allocated_rect.pos.y),
			i32(glyph.size.x), i32(glyph.size.y),
			gl.RED,
			gl.UNSIGNED_BYTE,
			font.face.glyph.bitmap.buffer
		);
		gl.BindTexture(gl.TEXTURE_2D, 0);
		return glyph, true;
	}
	return {}, false;
}
