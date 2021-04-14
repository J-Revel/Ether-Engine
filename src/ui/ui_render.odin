package ui;

import "core:os"
import "core:strings"
import "core:log"

import gl "shared:odin-gl"

import "../render"

Render_State :: struct
{
    shader: u32,

    screenSizeAttrib: i32,

    vao: u32,
    element_buffer: u32,
}

Render_System :: struct
{
	index: [dynamic]u32,
    render_state: Render_State,
    current_texture: render.Texture_Handle,
    current_pass_index: int,
}

init_renderer:: proc(using render_system: ^Render_System) -> bool
{ 
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER);
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER);
	vertex_shader_src, fragment_shader_src: []u8;
	ok: bool;
	vertex_shader_src, ok = os.read_entire_file("resources/shaders/ui.vert", context.temp_allocator);
	assert(ok);
	fragment_shader_src, ok = os.read_entire_file("resources/shaders/ui.frag", context.temp_allocator);
	assert(ok);
	vertex_shader_cstring := &vertex_shader_src[0];
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_cstring, nil);
	gl.CompileShader(vertex_shader);
	
	vert_ok: i32;
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok);
	if vert_ok != gl.TRUE
	{
		error_length: i32;
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length);
		log.info(error_length);
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
		gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0]);
		log.errorf(string(error));
	}
	
	fragment_shader_cstring := &fragment_shader_src[0];
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, nil);
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
	}

	render_system.render_state.shader = gl.CreateProgram();
    gl.AttachShader(render_system.render_state.shader, vertex_shader);
    gl.AttachShader(render_system.render_state.shader, fragment_shader);
	gl.LinkProgram(render_system.render_state.shader);

	link_ok: i32;
    gl.GetProgramiv(render_system.render_state.shader, gl.LINK_STATUS, &link_ok);
    if link_ok != gl.TRUE {
		error_length: i32;
		gl.GetProgramiv(render_system.render_state.shader, gl.INFO_LOG_LENGTH, &error_length);
		log.info(error_length);
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
		gl.GetProgramInfoLog(render_system.render_state.shader, error_length, nil, &error[0]);
		log.errorf(string(error));
        return false;
    }
	return true;
}
