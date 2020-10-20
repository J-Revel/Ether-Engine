package render
import sdl_image "shared:odin-sdl2/image"
import sdl "shared:odin-sdl2"
import "core:strings"
import "core:log"
import gl "shared:odin-gl";
import "../util/container"

@(private="package")
sprite_fragment_shader_src :: `
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

@(private="package")
sprite_vertex_shader_src :: `
#version 450
layout (location = 0) in vec2 pos;
layout(location = 1) in vec2 uv;
layout (location = 2) in vec4 color;
out vec4 frag_color;
out vec2 frag_pos;
out vec2 frag_uv;

uniform vec2 screenSize;
uniform vec3 camPosZoom;

void main()
{
    frag_color = color;
    frag_pos = pos;
    frag_uv = uv;
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
	anchor: [2]f32,
	clip: Rect,
}

Sprite_Vertex_Data :: struct
{
    pos: vec2,
    uv: vec2,
    color: Color
}

Sprite_Render_Buffer :: Render_Buffer(Sprite_Vertex_Data);
Sprite_Render_System :: Render_System(Sprite_Vertex_Data);

load_texture :: proc(path: string) -> Texture
{
	cstring_path := strings.clone_to_cstring(path, context.temp_allocator);
	surface := sdl_image.load(cstring_path);
	defer sdl.free_surface(surface);
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
	return {texture_id, {int(surface.w), int(surface.h)}};
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
    	error_length: i32;
    	gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length);
    	error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
    	gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0]);
        log.errorf("Unable to compile vertex shader: {}", cstring(&error[0]));
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
    gl.VertexAttribPointer(1, 2, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), rawptr(uintptr(size_of(vec2))));
    gl.VertexAttribPointer(2, 4, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), rawptr(uintptr(size_of(vec2) * 2)));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);
    gl.EnableVertexAttribArray(2);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    return true;
}

render_sprite :: proc(render_buffer: ^Render_Buffer(Sprite_Vertex_Data), using sprite: Sprite, pos: [2]f32, color: Color, scale: f32)
{
    start_index := cast(u32) len(render_buffer.vertex);

    texture_size_i := container.handle_get(texture).size;

    texture_size: [2]f32 = {f32(texture_size_i.x), f32(texture_size_i.y)};
    clip_size := [2]f32{
    	clip.size.x > 0 ? clip.size.x : 1,
    	clip.size.y > 0 ? clip.size.y : 1
    };
    render_size := texture_size * clip_size;

    vertex_data : Sprite_Vertex_Data;
    left_pos := pos.x - render_size.x * anchor.x;
    right_pos := pos.x + render_size.x * (1 - anchor.x);
    top_pos := pos.y - render_size.y * anchor.y;
    bottom_pos := pos.y + render_size.y * (1 - anchor.y);

    left_uv := clip.pos.x;
    right_uv := clip.pos.x + clip_size.x;
    top_uv := clip.pos.y;
    bottom_uv := clip.pos.y + clip_size.y;

    vertex_data.pos = [2]f32{left_pos, top_pos};
    vertex_data.uv = sprite.clip.pos;
    append(&render_buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{right_pos, top_pos};
    vertex_data.uv = clip.pos;
    append(&render_buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{left_pos, bottom_pos};
    vertex_data.uv = sprite.clip.pos;
    append(&render_buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{right_pos, bottom_pos};
    vertex_data.uv = sprite.clip.pos;
    append(&render_buffer.vertex, vertex_data);

    append(&render_buffer.index, start_index);
    append(&render_buffer.index, start_index + 1);
    append(&render_buffer.index, start_index + 2);
    append(&render_buffer.index, start_index + 1);
    append(&render_buffer.index, start_index + 2);
    append(&render_buffer.index, start_index + 3);
}

// TODO : system to load/save sprites