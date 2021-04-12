package ui

import gl "shared:odin-gl"
import "core:strings"
import "core:log"

@(private="package")
vertex_shader_src :: `
#version 450
struct Rect 
{
	float x, y, w, h;
	int color;
}

struct Circle
{
	float x, y, r;
	int color;
}

layout(std430, binding = 1) buffer draw_commands
{
	Rect rects[1000];
	Circle circles[1000];
};

out vec4 frag_color;
out vec2 frag_pos;
out vec2 frag_uv;

uniform vec2 screenSize;

void main()
{
	gl_VertexID
    frag_color = color;
    frag_pos = pos;
    frag_uv = uv;
    vec2 screenPos = pos.xy * 2 / screenSize - vec2(1, 1);
    gl_Position = vec4(screenPos.x, -screenPos.y,0,1);
}
`;

@(private="package")
fragment_shader_src :: `
#version 450
in vec4 frag_color;
in vec2 frag_pos;
in vec2 frag_uv;
layout (location = 0) out vec4 out_color;
uniform sampler2D tex;

void main()
{
    out_color = frag_color * texture(tex, frag_uv);
}
`;

INDEX_BUFFER_SIZE :: 50000;
STORAGE_BUFFER_SIZE :: 20000;

init_ui_renderer :: proc (result: ^UI_Render_State) -> bool
{
    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER);
    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER);
	vertex_shader_src: string;

    vertex_shader_cstring := cast(^u8)strings.clone_to_cstring(vertex_shader_src, context.temp_allocator);
    fragment_shader_cstring := cast(^u8)strings.clone_to_cstring(fragment_shader_src, context.temp_allocator);
    gl.ShaderSource(vertex_shader, 1, &vertex_shader_cstring, nil);
    gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, nil);
    gl.CompileShader(vertex_shader);
    gl.CompileShader(fragment_shader);
    frag_ok: i32;
    vert_ok: i32;
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok);
    if vert_ok != gl.TRUE {
    	error_length: i32;
    	gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length);
    	error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
    	gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0]);
        log.errorf("Unable to compile vertex shader: {}", cstring(&error[0]));
        return false;
    }
    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &frag_ok);
    if frag_ok != gl.TRUE || vert_ok != gl.TRUE {
        log.errorf("Unable to compile fragment shader: {}", fragment_shader_src);
        return false;
    }

    result.shader = gl.CreateProgram();
    gl.AttachShader(result.shader, vertex_shader);
    gl.AttachShader(result.shader, fragment_shader);
    gl.LinkProgram(result.shader);
    ok: i32;
    gl.GetProgramiv(result.shader, gl.LINK_STATUS, &ok);
    if ok != gl.TRUE {
        log.errorf("Error linking program: {}", result.shader);
        return true;
    }

    result.screenSizeAttrib = gl.GetUniformLocation(result.shader, "screenSize");
    
    gl.GenVertexArrays(1, &result.vao);
    gl.GenBuffers(1, &result.elementBuffer);
	gl.GenBuffers(1, &result.ssbo);

    gl.BindVertexArray(result.vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, result.elementBuffer);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW);

	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, result.ssbo);
	gl.BufferData(gl.SHADER_STORAGE_BUFFER, STORAGE_BUFFER_SIZE * size_of(Rect_Draw_Command), nil, gl.DYNAMIC_DRAW);
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, result.ssbo);

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
    gl.BindVertexArray(0);

    //result.default_texture = generate_default_white_texture();

    return true;
}
