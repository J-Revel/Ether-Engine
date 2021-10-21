package custom_imgui;

import "core:os"
import "core:strings"
import "core:log"
import "core:math/linalg"

import gl "vendor:OpenGL"

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
	gl.BufferData(gl.SHADER_STORAGE_BUFFER, SSBO_SIZE * size_of(GPU_Rect_Command), nil, gl.DYNAMIC_DRAW);
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
	vertex_cstring := cstring(&vertex_shader_src[0]);
	strlen : i32 = i32(len(vertex_shader_src));
	gl.ShaderSource(vertex_shader, 1, &vertex_cstring, &strlen);
	gl.CompileShader(vertex_shader);
	
	vert_ok: i32;
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok);
	if vert_ok == 0 
	{
		error_length: i32;
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length);
		error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
		gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0]);
		log.errorf(string(error));
		panic("vertex shader compilation error");
	}
	
	fragment_shader_cstring := cstring(&fragment_shader_src[0]);
	strlen = i32(len(fragment_shader_src));
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, &strlen);
	gl.CompileShader(fragment_shader);
	
	frag_ok: i32;
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &frag_ok);
	if frag_ok == 0
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
    if link_ok == 0 {
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

reset_draw_list :: proc(using draw_list: ^Draw_Command_List, screen_size: [2]int)
{
	clear(&clips);
	append(&clips, UI_Rect{{0, 0}, screen_size});
	clear(&clip_stack);
	append(&clip_stack, 0);
	clear(&commands);
}

push_clip :: proc(using draw_list: ^Draw_Command_List, clip_rect: UI_Rect)
{
	append(&clips, clip_rect);
	new_clip_index := len(clip_stack);
	append(&clip_stack, new_clip_index);
}

pop_clip :: proc(using draw_list: ^Draw_Command_List)
{
	pop(&clip_stack);
}

add_rect_command :: proc(using draw_list: ^Draw_Command_List, rect_command: Rect_Command, element: Element_ID) -> ^Computed_Rect_Command
{
	append(&commands, Computed_Rect_Command{
		command = rect_command,
		clip_index = clip_stack[len(clip_stack) - 1],
		parent = element,
	});
	return &commands[len(commands) - 1];
}

compute_gpu_commands :: proc(screen_rect: UI_Rect, draw_list: ^Draw_Command_List, hierarchy_rects: []UI_Rect, allocator := context.allocator) -> GPU_Command_List
{
	result: GPU_Command_List;
	result.commands = make([]GPU_Rect_Command, len(draw_list.commands), allocator);
	result.index = make([]u32, len(draw_list.commands) * 6, allocator);
	for i in 0..<len(draw_list.commands)
	{
		rect_command := &draw_list.commands[i];
		display_rect := compute_child_rect(hierarchy_rects[rect_command.parent], rect_command.rect);
		parent_position : [2]i32;

		result.commands[i] = GPU_Rect_Command {
			pos = linalg.to_i32(display_rect.pos),
			size = linalg.to_i32(display_rect.size),
			uv_pos = rect_command.uv_clip.pos,
			uv_size = rect_command.uv_clip.size,
			color = u32(rect_command.theme.fill_color),
			border_color = u32(rect_command.theme.border_color),
			border_thickness = i32(rect_command.theme.border_thickness),
			texture_id = rect_command.texture_id,
			clip_index = i32(rect_command.clip_index),
		};

		switch radius in rect_command.theme.corner_radius
		{
			case f32:
				result.commands[i].corner_radius = i32(f32(display_rect.size.y) * radius);
			case int:
				result.commands[i].corner_radius = i32(radius);
		}
		
		result.index[i * 6 + 0] = u32(i) * (1<<16) + 0;
		result.index[i * 6 + 1] = u32(i) * (1<<16) + 1;
		result.index[i * 6 + 2] = u32(i) * (1<<16) + 2;
		result.index[i * 6 + 3] = u32(i) * (1<<16) + 1;
		result.index[i * 6 + 4] = u32(i) * (1<<16) + 3;
		result.index[i * 6 + 5] = u32(i) * (1<<16) + 2;
	}
	result.clips = draw_list.clips[:];
	return result;
}

render_ui_draw_list :: proc(using render_system: ^Render_System, draw_list: ^GPU_Command_List, viewport: render.Viewport, texture: ^render.Texture)
{
	gl.BindVertexArray(render_system.vao);
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_system.primitive_buffer);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, primitive_buffer);
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 4, ubo);

	gpu_clips := make([]GPU_Rect, len(draw_list.clips), context.temp_allocator);
	for clip, i in draw_list.clips
	{
		gpu_clips[i] = GPU_Rect {
			pos = linalg.to_i32(clip.pos),
			size = linalg.to_i32(clip.size),
		};
	}
		
	gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, int(len(draw_list.clips)) * size_of(GPU_Rect), &gpu_clips[0]);
	gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 256 * size_of(util.Rect), int(len(draw_list.commands)) * size_of(GPU_Rect_Command), &draw_list.commands[0]);
	if len(draw_list.index) > 0
	{
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_system.element_buffer);
		gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) len(draw_list.index) * size_of(u32), &draw_list.index[0]);
	}

	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo);
	ubo_data := Ubo_Data{[2]i32{i32(viewport.size.x), i32(viewport.size.y)}, {}};
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
}
