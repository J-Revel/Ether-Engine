package windows_sdl_backend

import platform_layer "../base"
import stbtt "vendor:stb/truetype"

fonts: map[Font_Handle]Packed_Font
next_handle: Font_Handle

Packed_Font :: struct {
	render_height: f32,
	render_scale: f32,
	ascent: i32,
	descent: i32,
	linegap: i32,
	glyph_data: map[rune]Packed_Glyph_Data,
	atlas_texture: Texture_Handle,
	atlas_size: [2]i32,
}

Packed_Glyph_Data :: struct {
	rect: I_Rect,
	offset: [2]i32,
	advance: i32,
	left_side_bearing: i32,
}

load_font :: proc(file_path: string, allocator := context.allocator) -> Font_Handle {
	fontinfo: stb_tt.fontinfo
	fontdata, fontdata_ok := platform_layer.instance.load_file("resources/fonts/Roboto-Regular.ttf", context.temp_allocator)
	stb_tt.InitFont(&fontinfo, &fontdata[0], 0)
	next_handle += 1
	fonts[next_handle] = pack_font_characters(ui_state, &fontinfo, " !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~éèàç", font_atlas_size, allocator)
	return next_handle
}

free_font :: proc(font_handle: platform_layer.Font_Handle) {

}

get_font_metrics :: proc(font_handle: platform_layer.Font_Handle) {

}

pack_font_characters :: proc(
	using ui_state: ^UI_State,
	fontinfo: ^stb_tt.fontinfo,
	characters: string,
	atlas_size: [2]int,
	allocator := context.allocator,
) -> (out_atlas: Packed_Font) {
	cursor: [2]int = {}
	next_line_height := 0
	atlas_data := make([]u8, atlas_size.x * atlas_size.y, allocator)
	glyph_data := make(map[rune]Packed_Glyph_Data, 1000, allocator)

	sdf_render_height : f32 = 40

	ascent, descent, linegap: i32
	stb_tt.GetFontVMetrics(fontinfo, &ascent, &descent, &linegap)
	render_scale := stb_tt.ScaleForPixelHeight(fontinfo, sdf_render_height)

	for c in characters {
		glyph_rect: I_Rect
		glyph_offset: [2]i32
		glyph_advance, glyph_bearing: i32
		stb_tt.GetCodepointHMetrics(fontinfo, c, &glyph_advance, &glyph_bearing)
		glyph := cast([^]u8)stb_tt.GetCodepointSDF(
			fontinfo, render_scale, i32(c), 20, 180, 180/20,
			&glyph_rect.size.x, &glyph_rect.size.y,
			&glyph_offset.x, &glyph_offset.y,
		)
		if cursor.x + int(glyph_rect.size.x) >= atlas_size.x {
			cursor.y = next_line_height
			cursor.x = 0
		}
		if next_line_height < cursor.y + int(glyph_rect.size.y) {
			next_line_height = cursor.y + int(glyph_rect.size.y)
		}
		glyph_rect.pos = linalg.to_i32(cursor)
		
		for i :int= 0;i<int(glyph_rect.size.y); i+=1 {
			for j :int= 0; j<int(glyph_rect.size.x); j+=1 {
				atlas_data[cursor.x + j + (cursor.y + i) * atlas_size.x] = glyph[j + i * int(glyph_rect.size.x)]
			}
		}
		glyph_data[c] = Packed_Glyph_Data{
			rect = glyph_rect,
			offset = glyph_offset,
			advance = glyph_advance,
			left_side_bearing = glyph_bearing,
		}
		cursor.x += int(glyph_rect.size.x)
	}
	atlas_texture_data : Texture_Data = {
		data = atlas_data,
		size = atlas_size,
		texture_format = .R
	}

	return Packed_Font{
		render_height = sdf_render_height,
		render_scale = render_scale,
		ascent = ascent,
		descent = descent,
		linegap = linegap,
		glyph_data = glyph_data,
		atlas_texture = render_system->load_texture(&atlas_texture_data),
		atlas_size = linalg.to_i32(atlas_size),
	}

}

font_pack_to_texture :: proc(atlas_data: []u8, atlas_size: [2]int) -> Texture {
	texture_id: u32
	// gl.GenTextures(1, &texture_id)
	// gl.BindTexture(gl.TEXTURE_2D, texture_id)

	// gl.TexImage2D(gl.TEXTURE_2D, 0, i32(gl.RED), i32(atlas_size.x), i32(atlas_size.y), 0, u32(gl.RED), gl.UNSIGNED_BYTE, &atlas_data[0])
	 
	// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	// bindless_id := render.GetTextureHandleARB(texture_id)
	// render.MakeTextureHandleResidentARB(bindless_id)
	return Texture{
		texture_id = texture_id,
		bindless_id = 0,
		resident = true,
		size = atlas_size,
	}
}