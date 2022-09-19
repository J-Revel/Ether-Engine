package imgui_opengl

import imgui ".."

	fonts: ^map[string]Packed_Font,
import imgui ".."

opengl_render_draw_commands :: proc(
	render_system: ^OpenGL_Render_System,
	draw_list: ^Command_List,
	viewport: I_Rect,
import imgui ".."

	fonts: ^map[string]Packed_Font,
	fonts: ^map[string]Packed_Font,
) {

	gl.BindVertexArray(render_system.vao)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.rect_primitive_buffer)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, render_system.rect_primitive_buffer)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.glyph_primitive_buffer)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 4, render_system.glyph_primitive_buffer)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 5, render_system.ubo)

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
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.glyph_primitive_buffer)
	
	if len(draw_list.glyph_commands) > 0
	{
		gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, int(len(draw_list.glyph_commands)) * size_of(Glyph_Command), &draw_list.glyph_commands[0])
	}
	if len(draw_list.index) > 0
	{
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_system.element_buffer)
		gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) len(draw_list.index) * size_of(u32), &draw_list.index[0])
	}

	gl.BindBuffer(gl.UNIFORM_BUFFER, render_system.ubo)
	ubo_data := Ubo_Data{viewport.size, {}}
	gl.BufferSubData(gl.UNIFORM_BUFFER, 0, cast(int)size_of(Ubo_Data), &ubo_data)

	gl.BindVertexArray(0)
	gl.BindTexture(gl.TEXTURE_2D, fonts["default"].atlas_texture.texture_id)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)

	gl.UseProgram(render_system.shader)
	gl.Uniform2f(render_system.screen_size_attrib, f32(viewport.size.x), f32(viewport.size.y))
	//render.UniformHandleui64ARB(texture_attrib, texture.bindless_id)

	gl.BindVertexArray(render_system.vao)
	gl.DrawElements(gl.TRIANGLES, cast(i32) 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
	gl.UseProgram(0)
}

create_opengl_renderer :: proc() -> (OpenGL_Render_System, bool)
{ 
	render_system: OpenGL_Render_System
	using render_system

	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &element_buffer)
	gl.GenBuffers(1, &rect_primitive_buffer)
	gl.GenBuffers(1, &glyph_primitive_buffer)
	gl.GenBuffers(1, &render_system.ubo)
	
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
        return {}, false
    }
	render_system.screen_size_attrib = gl.GetUniformLocation(render_system.shader, "screenSize")
	// for i : int = 0;i<font_atlas_size.y; i+=1 {
	// 	for j : int = 0; j<font_atlas_size.x; j+=1 {
	// 		fmt.print((atlas.glyph_data[j + i * font_atlas_size.x] > 180 ? "O":" "))
	// 	}
	// 	fmt.println()
	// }
	// log.info(glyph_data)
	return render_system, true
}