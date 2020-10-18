package render
import sdl_image "shared:odin-sdl2/image"
import "core:strings"
import "core:log"
import gl "shared:odin-gl";

@(private="package")
sprite_fragment_shader_src :: `
#version 450
in vec4 frag_color;
in vec2 frag_pos;
layout (location = 0) out vec4 out_color;

void main()
{
    out_color = 1 - ((1 - frag_color) * (1 - frag_color));
}
`;

@(private="package")
sprite_vertex_shader_src :: `
#version 450
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 color;
out vec4 frag_color;
out vec2 frag_pos;

uniform vec2 screenSize;
uniform vec3 camPosZoom;

void main()
{
    frag_color = color;
    frag_pos = pos;
    float zoom = camPosZoom.z;
    vec2 camPos = camPosZoom.xy;
    gl_Position = vec4((pos.xy - camPos) * 2 / screenSize * camPosZoom.z,0,1);
}
`;

Rect :: struct
{
	pos: [2]f32,
	size: [2]f32
}

Texture :: struct
{
	texture_id: u32,
	size: [2]int,
}

Sprite :: struct
{
	texture: container.Handle(Texture),
	clip: Rect,
}

load_texture :: proc(path: string) -> u32
{
	cstring_path := strings.clone_to_cstring(path, context.temp_allocator);
	surface := sdl_image.load(cstring_path);
	log.info(path, surface);
	texture_id: u32;
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);

	mode := gl.RGB;
 	log.info(surface.format);
 	
	if surface.format.bytes_per_pixel == 4 do mode = gl.RGBA;
	 
	gl.TexImage2D(gl.TEXTURE_2D, 0, i32(mode), surface.w, surface.h, 0, u32(mode), gl.UNSIGNED_BYTE, surface.pixels);
	 
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
	return 0;
}

Sprite_Vertex_Data :: struct
{
    pos: vec2,
    uv: vec2,
    color: Color
}

init_sprite_renderer :: proc (result: ^Render_State) -> bool
{
    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER);
    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER);
    vertex_shader_cstring := cast(^u8)strings.clone_to_cstring(sprite_vertex_shader_src, context.temp_allocator);
    fragment_shader_cstring := cast(^u8)strings.clone_to_cstring(sprite_fragment_shader_src, context.temp_allocator);
    gl.ShaderSource(vertex_shader, 1, &vertex_shader_cstring, nil);
    gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, nil);
    gl.CompileShader(vertex_shader);
    gl.CompileShader(fragment_shader);
    frag_ok: i32;
    vert_ok: i32;
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok);
    if vert_ok != gl.TRUE {
        log.errorf("Unable to compile vertex shader: {}", sprite_vertex_shader_src);
        return false;
    }
    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &frag_ok);
    if frag_ok != gl.TRUE || vert_ok != gl.TRUE {
        log.errorf("Unable to compile fragment shader: {}", sprite_fragment_shader_src);
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

    result.camPosZoomAttrib = gl.GetUniformLocation(result.shader, "camPosZoom");
    result.screenSizeAttrib = gl.GetUniformLocation(result.shader, "screenSize");
    
    gl.GenVertexArrays(1, &result.vao);
    gl.GenBuffers(1, &result.vbo);
    gl.GenBuffers(1, &result.elementBuffer);

    gl.BindVertexArray(result.vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, result.vbo);
    gl.BufferData(gl.ARRAY_BUFFER, VERTEX_BUFFER_SIZE * size_of(Sprite_Vertex_Data), nil, gl.DYNAMIC_DRAW);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, result.elementBuffer);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), nil);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), rawptr(uintptr(size_of(vec2))));
    gl.VertexAttribPointer(1, 4, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), rawptr(uintptr(size_of(vec2) * 2)));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    return true;
}

push_sprite_render_data :: proc(render_buffer: ^Render_Buffer($T), sprite: Sprite, pos: [2]f32, scale: f32)
{
    start_index := cast(u32) len(render_buffer.vertex);

    append(&render_buffer.vertex, pos + sprite.texture.size );
    for v in vertex
    {
        append(&render_buffer.vertex, v);
    }

    for i in index
    {
        append(&render_buffer.index, start_index + i);
    }
}

// TODO : system to load/save sprites