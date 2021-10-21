package render

import "core:log"
import "core:math/linalg"
import "core:fmt"
import "core:runtime"

import gl "vendor:OpenGL"

import "../../libs/freetype"

import "../container"
import "../util"

lib: freetype.Library;

init_font_render :: proc()
{
	//freetype.init(&lib);
}

load_font :: proc(path: string, size: int, allocator := context.allocator) -> (font: ^Font, ok: bool)
{
	font = new(Font, allocator);
	// error := freetype.new_face(lib, path, 0, &font.face);
	// if error != .OK
	// {
	// 	log.error("Font load error", error);
	// 	return font, false;
	// }
	// freetype.set_pixel_sizes(font.face, 0, u32(size));
	// font.line_height = f32(font.face.size.metrics.height)/64;
	// font.ascent = f32(font.face.size.metrics.ascender)/64;
	// font.descent = f32(font.face.size.metrics.descender)/64;
	return font, true;
}

free_font :: proc(font: ^Font)
{
	// freetype.free_face(font.face);
}

load_single_glyph :: proc(using font: Font, character: rune) -> (glyph: Glyph, texture_id: u32, ok: bool)
{
	// error := freetype.load_char(font.face, u32(character), freetype.LOAD_RENDER);
	// if error != .OK do return {}, 0, false;
	// gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	// gl.GenTextures(1, &texture_id);
	// gl.BindTexture(gl.TEXTURE_2D, texture_id);
	// glyph.size = [2]int {
	// 	int(face.glyph.bitmap.width),
	// 	int(face.glyph.bitmap.rows),
	// };
	// bitmap := &face.glyph.bitmap;
	// gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
	// gl.TexImage2D(
	// 	gl.TEXTURE_2D,
	// 	0,
	// 	gl.RED,
	// 	i32(glyph.size.x), i32(glyph.size.y),
	// 	0,
	// 	gl.RED,
	// 	gl.UNSIGNED_BYTE,
	// 	face.glyph.bitmap.buffer,
	// );
	// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	// gl.BindTexture(gl.TEXTURE_2D, 0);

	glyph = Glyph{
		size = [2]int{int(10), int(10)},
		bearing = [2]int{int(0), int(0)},
		advance = [2]int{int(0), int(0)},
	};
	// glyph = Glyph{
	// 	size = [2]int{int(bitmap.width), int(bitmap.rows)},
	// 	bearing = [2]int{int(face.glyph.bitmap_left), int(face.glyph.bitmap_top)},
	// 	advance = [2]int{int(face.glyph.advance.x), int(face.glyph.advance.y)},
	// };
	return glyph, 0, true;
}

init_font_atlas :: proc(texture_table: ^container.Table(Texture), atlas: ^Font_Atlas, texture_size := 2048)
{
	texture_id: u32;
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	pixels := make([]u8, texture_size * texture_size * 4, context.allocator);
	defer delete(pixels);
	for i in 0..<texture_size * texture_size
	{
		pixels[i] = i % 4 == 3 ? 0:255;
	}
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGBA,
		i32(texture_size), i32(texture_size),
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		&pixels[0],
	);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	gl.BindTexture(gl.TEXTURE_2D, 0);
	ok: bool;
	bindless_id := GetTextureHandleARB(texture_id);
	log.info(GetTextureHandleARB(texture_id));
	log.info(GetTextureHandleARB(texture_id));
	log.info(GetTextureHandleARB(texture_id));
	log.info(GetTextureHandleARB(texture_id));
	MakeTextureHandleResidentARB(bindless_id);
	atlas.texture_handle, ok = container.table_add(texture_table, Texture{
		texture_id = texture_id,
		size = [2]int{texture_size, texture_size},
		bindless_id = bindless_id,
	});


	assert(ok);
	init_atlas(&atlas.pack_tree, [2]f32{f32(texture_size), f32(texture_size)});
	atlas.texture_size = [2]int{texture_size, texture_size};
}

load_glyph :: proc(using font_atlas: ^Font_Atlas, font: ^Font, character: rune, sprite_table: ^container.Table(Sprite)) -> (glyph: Glyph, ok: bool)
{
	// error := freetype.load_char(font.face, u32(character), freetype.LOAD_RENDER);
	// if error != .OK do return {}, false;
	// glyph.size = [2]int {
	// 	int(font.face.glyph.bitmap.width),
	// 	int(font.face.glyph.bitmap.rows),
	// };
	// bitmap := &font.face.glyph.bitmap;

	// glyph = Glyph{
	// 	size = [2]int{int(bitmap.width), int(bitmap.rows)},
	// 	bearing = [2]int{int(font.face.glyph.bitmap_left), int(-font.face.glyph.bitmap_top)},
	// 	advance = [2]int{int(font.face.glyph.advance.x), 0},
	// };
	// allocated_rect, alloc_ok := allocate_rect(&font_atlas.pack_tree, [2]f32{f32(bitmap.width), f32(bitmap.rows)});
	// assert(alloc_ok);
	// uv_rect := util.Rect{allocated_rect.pos / linalg.to_f32(texture_size), allocated_rect.size / linalg.to_f32(texture_size)};
	// add_ok: bool;
	// sprite :=  Sprite {
	// 	texture = font_atlas.texture_handle,
	// 	id = fmt.aprint("char", character),
	// 	data = {
	// 		clip = uv_rect,
	// 	},
	// };
	// glyph.sprite, add_ok = container.table_add(sprite_table, sprite);
	// assert(add_ok);
	// if alloc_ok
	// {
	// 	texture_data := container.handle_get(texture_handle);
	// 	pixels := make([]u8, glyph.size.x * glyph.size.y * 4, context.allocator);
	// 	defer delete(pixels);
	// 	bitmap_data := transmute([]u8)runtime.Raw_Slice{font.face.glyph.bitmap.buffer, glyph.size.x * glyph.size.y};
	// 	for i in 0..<glyph.size.x * glyph.size.y
	// 	{
	// 		pixels[i * 4] = 255;
	// 		pixels[i * 4 + 1] = 255;
	// 		pixels[i * 4 + 2] = 255;
	// 		pixels[i * 4 + 3] = bitmap_data[i];
	// 	}
	// 	gl.BindTexture(gl.TEXTURE_2D, texture_data.texture_id);
	// 	if glyph.size.x * glyph.size.y > 0
	// 	{
	// 		/*gl.TexSubImage2D(
	// 			gl.TEXTURE_2D,
	// 			0,
	// 			i32(allocated_rect.pos.x),
	// 			i32(allocated_rect.pos.y),
	// 			i32(glyph.size.x), i32(glyph.size.y),
	// 			gl.RGBA,
	// 			gl.UNSIGNED_BYTE,
	// 			&pixels[0],
	// 		);*/
	// 	}
	// 	gl.BindTexture(gl.TEXTURE_2D, 0);
	// 	font.glyphs[character] = glyph;
	// 	return glyph, true;
	// }
	return {}, false;
}

load_glyphs :: proc(atlas: ^Font_Atlas, sprite_table: ^container.Table(Sprite), font: ^Font, text: string)
{
	for char in text
	{
		if char not_in font.glyphs
		{
			/*glyph, glyph_ok := */load_glyph(atlas, font, char, sprite_table);

		}
	}

}

get_text_render_size :: proc(font: ^Font, text: string) -> (out_size: int)
{
	for char in text
	{
		glyph, glyph_found := font.glyphs[char]; 
		if glyph_found
		{
			out_size += glyph.advance.x / 64;
		}
	}
	return out_size;
}

split_text_for_render :: proc(font: ^Font, text: string, line_size: int, allocator := context.temp_allocator) -> []string
{
	substring_size : int = 0;
	substring_start : int = 0;
	last_splittable_index: int = 0;
	last_split_size: int = 0;
	substrings: [dynamic]string;
	for char, index in text
	{
		glyph, glyph_found := font.glyphs[char];
		substring_size += glyph.advance.x / 64;
		last_split_size += glyph.advance.x / 64;
		if char == ' '
		{
			last_splittable_index = index;
			last_split_size = 0;
		}
		if substring_size >= line_size
		{
			append(&substrings, text[substring_start:last_splittable_index]);
			substring_start = last_splittable_index + 1;
			substring_size = last_split_size;
		}
	}
	out_substrings := make([]string, len(substrings) + 1, allocator);
	for substring, index in substrings
	{
		out_substrings[index] = substring;
	}
	out_substrings[len(substrings)] = text[substring_start:len(text)];
	return out_substrings;
}
