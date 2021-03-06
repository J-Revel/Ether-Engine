package ui;

import "core:os"
import "core:strings"
import "core:log"
import "core:math/linalg"

import gl "shared:odin-gl"

import "../render"
import "../util"

init_renderer:: proc(using render_system: ^Render_System) -> bool
{ 
	gl.GenVertexArrays(1, &vao);
	gl.GenBuffers(1, &element_buffer);
	gl.GenBuffers(1, &primitive_buffer);
	gl.GenBuffers(1, &ubo);
	
	gl.BindVertexArray(vao);
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer);
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW);
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, primitive_buffer);
	gl.BufferData(gl.SHADER_STORAGE_BUFFER, SSBO_SIZE * size_of(Draw_Command_Data), nil, gl.DYNAMIC_DRAW);
	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo);
	gl.BufferData(gl.UNIFORM_BUFFER, size_of(Ubo_Data), nil, gl.DYNAMIC_DRAW);
	
	gl.BindVertexArray(0);

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER);
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER);
	vertex_shader_src, fragment_shader_src: []u8;
	ok: bool;
	vertex_shader_src, ok = os.read_entire_file("resources/shaders/ui.vert", context.temp_allocator);
	assert(ok);
	fragment_shader_src, ok = os.read_entire_file("resources/shaders/ui.frag", context.temp_allocator);
	assert(ok);
	vertex_cstring := &vertex_shader_src[0];
	strlen : i32 = i32(len(vertex_shader_src));
	gl.ShaderSource(vertex_shader, 1, &vertex_cstring, &strlen);
	gl.CompileShader(vertex_shader);
	
	vert_ok: i32;
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok);
	if vert_ok != gl.TRUE
	{
		error_length: i32;
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length);
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
		gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0]);
		log.errorf(string(error));
		panic("vertex shader compilation error");
	}
	
	fragment_shader_cstring := &fragment_shader_src[0];
	strlen = i32(len(fragment_shader_src));
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, &strlen);
	gl.CompileShader(fragment_shader);
	
	frag_ok: i32;
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &frag_ok);
	if frag_ok != gl.TRUE
	{
		error_length: i32;
		gl.GetShaderiv(fragment_shader, gl.INFO_LOG_LENGTH, &error_length);
		log.info(error_length);
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
		gl.GetShaderInfoLog(fragment_shader, error_length, nil, &error[0]);
		log.errorf(string(error));
		panic("fragment shader compilation error");
	}

	render_system.shader = gl.CreateProgram();
    gl.AttachShader(render_system.shader, vertex_shader);
    gl.AttachShader(render_system.shader, fragment_shader);
	gl.LinkProgram(render_system.shader);

	link_ok: i32;
    gl.GetProgramiv(render_system.shader, gl.LINK_STATUS, &link_ok);
    if link_ok != gl.TRUE {
		error_length: i32;
		gl.GetProgramiv(render_system.shader, gl.INFO_LOG_LENGTH, &error_length);
		log.info(error_length);
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
		gl.GetProgramInfoLog(render_system.shader, error_length, nil, &error[0]);
		log.errorf(string(error));
        return false;
    }
	//render_system.screen_size_attrib = gl.GetUniformLocation(render_system.shader, "screenSize");
	return true;
}

reset_draw_list :: proc(using draw_list: ^Draw_Command_List, screen_size: [2]f32)
{
	clips = {};
	append(&clips, util.Rect{{0, 0}, screen_size});
	clip_stack = {};
	append(&clip_stack, 0);
}

add_rect_command :: proc(using draw_list: ^Draw_Command_List, rect_command: Rect_Command)
{
	if rect_command_count >= len(commands)
	{
		append(&commands, Draw_Command_Data{});
	}

	command_index: i32 = i32(rect_command_count);
	commands[rect_command_count].rect = rect_command;
	commands[rect_command_count].clip_index = draw_list.clip_stack[len(draw_list.clip_stack) - 1];
	append(&index, command_index * (1<<16) + 0);
	append(&index, command_index * (1<<16) + 1);
	append(&index, command_index * (1<<16) + 2);
	append(&index, command_index * (1<<16) + 1);
	append(&index, command_index * (1<<16) + 3);
	append(&index, command_index * (1<<16) + 2);
	rect_command_count += 1;
}

render_ui_draw_list :: proc(using render_system: ^Render_System, draw_list: ^Draw_Command_List, viewport: render.Viewport, texture: ^render.Texture)
{
	gl.BindVertexArray(render_system.vao);
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.primitive_buffer);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, primitive_buffer);
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 4, ubo);

	gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, cast(int) len(draw_list.clips) * size_of(util.Rect), &draw_list.clips[0]);
	gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 256 * size_of(util.Rect), cast(int) len(draw_list.commands) * size_of(Draw_Command_Data), &draw_list.commands[0]);
	if len(draw_list.index) > 0
	{
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_system.element_buffer);
		gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) len(draw_list.index) * size_of(u32), &draw_list.index[0]);
	}

	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo);
	ubo_data := Ubo_Data{linalg.to_f32(viewport.size), {}};
	gl.BufferSubData(gl.UNIFORM_BUFFER, 0, cast(int)size_of(Ubo_Data), &ubo_data);

	gl.BindVertexArray(0);
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0);

	gl.UseProgram(shader);
	//gl.Uniform2f(screen_size_attrib, f32(viewport.size.x), f32(viewport.size.y));
	//render.UniformHandleui64ARB(texture_attrib, texture.bindless_id);

	gl.BindVertexArray(vao);
	gl.DrawElements(gl.TRIANGLES, cast(i32) len(draw_list.index), gl.UNSIGNED_INT, nil);
	gl.BindVertexArray(0);
	gl.UseProgram(0);

	clear(&draw_list.commands);
	clear(&draw_list.index);
	draw_list.rect_command_count = 0;
}
