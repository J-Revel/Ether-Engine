package imgui

import "core:os"
import "core:strings"
import "core:log"
import "core:math/linalg"
import "core:fmt"

import gl "vendor:OpenGL"
import stb_tt "vendor:stb/truetype"

import "../render"
import "../util"

font_atlas_size: [2]int = {256, 256}

init_renderer:: proc(using render_system: ^Render_System) -> bool
{ 
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &element_buffer)
	gl.GenBuffers(1, &rect_primitive_buffer)
	gl.GenBuffers(1, &glyph_primitive_buffer)
	gl.GenBuffers(1, &ubo)
	
	gl.BindVertexArray(vao)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, rect_primitive_buffer)
	gl.BufferData(gl.SHADER_STORAGE_BUFFER, SSBO_SIZE * size_of(Rect_Command), nil, gl.DYNAMIC_DRAW)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, glyph_primitive_buffer)
	gl.BufferData(gl.SHADER_STORAGE_BUFFER, SSBO_SIZE * size_of(Glyph_Command), nil, gl.DYNAMIC_DRAW)
	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
	gl.BufferData(gl.UNIFORM_BUFFER, size_of(Ubo_Data), nil, gl.DYNAMIC_DRAW)
	
	gl.BindVertexArray(0)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	vertex_shader_src, fragment_shader_src: []u8
	ok: bool
	vertex_shader_src, ok = os.read_entire_file("resources/shaders/ui.vert", context.temp_allocator)
	assert(ok)
	fragment_shader_src, ok = os.read_entire_file("resources/shaders/ui.frag", context.temp_allocator)
	assert(ok)
	vertex_cstring := cstring(&vertex_shader_src[0])
	strlen : i32 = i32(len(vertex_shader_src))
	gl.ShaderSource(vertex_shader, 1, &vertex_cstring, &strlen)
	gl.CompileShader(vertex_shader)
	
	vert_ok: i32
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok)
	if vert_ok == 0 
	{
		error_length: i32
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length)
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator)
		gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0])
		log.errorf(string(error))
		panic("vertex shader compilation error")
	}
	
	fragment_shader_cstring := cstring(&fragment_shader_src[0])
	strlen = i32(len(fragment_shader_src))
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, &strlen)
	gl.CompileShader(fragment_shader)
	
	frag_ok: i32
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &frag_ok)
	if frag_ok == 0
	{
		error_length: i32
		gl.GetShaderiv(fragment_shader, gl.INFO_LOG_LENGTH, &error_length)
		log.info(error_length)
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator)
		gl.GetShaderInfoLog(fragment_shader, error_length, nil, &error[0])
		log.errorf(string(error))
		panic("fragment shader compilation error")
	}

	render_system.shader = gl.CreateProgram()
    gl.AttachShader(render_system.shader, vertex_shader)
    gl.AttachShader(render_system.shader, fragment_shader)
	gl.LinkProgram(render_system.shader)

	link_ok: i32
    gl.GetProgramiv(render_system.shader, gl.LINK_STATUS, &link_ok)
    if link_ok == 0 {
		error_length: i32
		gl.GetProgramiv(render_system.shader, gl.INFO_LOG_LENGTH, &error_length)
		log.info(error_length)
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator)
		gl.GetProgramInfoLog(render_system.shader, error_length, nil, &error[0])
		log.errorf(string(error))
        return false
    }
	render_system.screen_size_attrib = gl.GetUniformLocation(render_system.shader, "screenSize")

	fontinfo: stb_tt.fontinfo
	fontdata, fontdata_ok := os.read_entire_file("resources/fonts/arial.ttf", context.temp_allocator)
	stb_tt.InitFont(&fontinfo, &fontdata[0], 0)
	atlas_data, glyph_data := pack_font_characters(&fontinfo, "abcdefhijklmnopqrstuvwxyzABCDEFHIJKLMNOPQRSTUVWXYZ0123456789", font_atlas_size)
	for i : int = 0;i<font_atlas_size.y; i+=1 {
		for j : int = 0; j<font_atlas_size.x; j+=1 {
			fmt.print((atlas_data[j + i * font_atlas_size.x] > 180 ? "O":" "))
		}
		fmt.println()
	}
	log.info(glyph_data)
	return true
}

pack_font_characters :: proc(
	fontinfo: ^stb_tt.fontinfo,
	characters: string,
	atlas_size: [2]int,
	allocator := context.allocator,
) -> (out_atlas_data: []u8, out_glyph_data: map[rune]Packed_Glyph_Data) {
	cursor: [2]int = {}
	next_line_height := 0
	out_atlas_data = make([]u8, atlas_size.x * atlas_size.y, allocator)
	out_glyph_data = make(map[rune]Packed_Glyph_Data, 1000, allocator)

	for c in characters {
		glyph_rect: I_Rect
		glyph_offset: [2]i32
		render_scale := stb_tt.ScaleForPixelHeight(fontinfo, 22)
		glyph_advance, glyph_bearing: i32
		stb_tt.GetCodepointHMetrics(fontinfo, c, &glyph_advance, &glyph_bearing)
		glyph := cast([^]u8)stb_tt.GetCodepointSDF(
			fontinfo, render_scale, i32(c), 5, 180, 36, 
			&glyph_rect.size.x, &glyph_rect.size.y, 
			&glyph_offset.x, &glyph_offset.y
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
				out_atlas_data[cursor.x + j + (cursor.y + i) * atlas_size.x] = glyph[j + i * int(glyph_rect.size.x)]
			}
		}
		out_glyph_data[c] = Packed_Glyph_Data{
			rect = glyph_rect,
			offset = glyph_offset,
			advance = glyph_advance,
			left_side_bearing = glyph_bearing,
		}
		cursor.x += int(glyph_rect.size.x)
	}
	return

}

render_draw_commands :: proc(
	using render_system: ^Render_System,
	draw_list: ^Command_List,
	viewport: I_Rect,
	// texture: ^render.Texture
) {
	gl.BindVertexArray(render_system.vao)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.rect_primitive_buffer)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, rect_primitive_buffer)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.glyph_primitive_buffer)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 4, glyph_primitive_buffer)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 5, ubo)

	gpu_clips := make([]I_Rect, len(draw_list.clips), context.temp_allocator)
	for clip, i in draw_list.clips
	{
		gpu_clips[i] = I_Rect {
			pos = linalg.to_i32(clip.pos),
			size = linalg.to_i32(clip.size),
		}
	}
	
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.rect_primitive_buffer)
	if len(gpu_clips) > 0
	{
		gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, int(len(draw_list.clips)) * size_of(I_Rect), &gpu_clips[0])
	}
	if len(draw_list.rect_commands) > 0
	{
		gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 256 * size_of(I_Rect), int(len(draw_list.rect_commands)) * size_of(Rect_Command), &draw_list.rect_commands[0])
	}
	if len(draw_list.index) > 0
	{
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_system.element_buffer)
		gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) len(draw_list.index) * size_of(u32), &draw_list.index[0])
	}


	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
	ubo_data := Ubo_Data{viewport.size, {}}
	gl.BufferSubData(gl.UNIFORM_BUFFER, 0, cast(int)size_of(Ubo_Data), &ubo_data)

	gl.BindVertexArray(0)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)

	gl.UseProgram(shader)
	gl.Uniform2f(screen_size_attrib, f32(viewport.size.x), f32(viewport.size.y))
	//render.UniformHandleui64ARB(texture_attrib, texture.bindless_id)

	gl.BindVertexArray(vao)
	gl.DrawElements(gl.TRIANGLES, cast(i32) len(draw_list.index), gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

add_rect_command :: proc(using draw_list: ^Command_List, rect_command: Rect_Command)
{
	if rect_command_count >= len(rect_commands)
	{
		append(&rect_commands, Rect_Command{})
	}

	command_index: u32 = u32(rect_command_count)
	rect_commands[rect_command_count] = rect_command
	append(&index, command_index * (1<<16) + 0)
	append(&index, command_index * (1<<16) + 1)
	append(&index, command_index * (1<<16) + 2)
	append(&index, command_index * (1<<16) + 1)
	append(&index, command_index * (1<<16) + 3)
	append(&index, command_index * (1<<16) + 2)
	rect_command_count += 1
}

reset_draw_list :: proc(using draw_list: ^Command_List, viewport: I_Rect)
{
	clear(&clips)
	append(&clips, viewport)
	clear(&draw_list.rect_commands)
	clear(&draw_list.glyph_commands)
	clear(&draw_list.index)
	rect_command_count = 0
}