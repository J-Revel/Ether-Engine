package render

import "core:mem";
import "core:log";
import "core:strings";
import "core:math";

import gl "shared:odin-gl";

@(private="package")
color_fragment_shader_src :: `
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
color_vertex_shader_src :: `
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

vec2 :: [2]f32;
Color :: [4]f32;

Render_State :: struct
{
    shader: u32,

    camPosZoomAttrib: i32,
    screenSizeAttrib: i32,

    vao: u32,
    vbo: u32,
    elementBuffer: u32,
}

Color_Vertex_Data :: struct
{
    pos: vec2,
    color: Color
}

Camera :: struct
{
    pos: vec2,
    zoom: f32,
}

INDEX_BUFFER_SIZE :: 50000;
VERTEX_BUFFER_SIZE :: 20000;


Render_Buffer :: struct(T: typeid)
{
    vertex: [dynamic]T,
    index: [dynamic]u32,
}

Render_System :: struct(T: typeid)
{
    screen_size: vec2,
    using buffer: Render_Buffer(T),
    render_state: Render_State,
}

Color_Render_Buffer :: Render_Buffer(Color_Vertex_Data);
Color_Render_System :: Render_System(Color_Vertex_Data);

init_color_renderer :: proc (result: ^Render_State) -> bool
{
    vertexShader := gl.CreateShader(gl.VERTEX_SHADER);
    fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER);
    vertexShaderText := cast(^u8)strings.clone_to_cstring(color_vertex_shader_src, context.temp_allocator);
    fragmentShaderText := cast(^u8)strings.clone_to_cstring(color_fragment_shader_src, context.temp_allocator);
    gl.ShaderSource(vertexShader, 1, &vertexShaderText, nil);
    gl.ShaderSource(fragmentShader, 1, &fragmentShaderText, nil);
    gl.CompileShader(vertexShader);
    gl.CompileShader(fragmentShader);
    fragOk: i32;
    vertOk: i32;
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &vertOk);
    if vertOk != gl.TRUE {
        log.errorf("Unable to compile vertex shader: {}", color_vertex_shader_src);
        return false;
    }
    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &fragOk);
    if fragOk != gl.TRUE || vertOk != gl.TRUE {
        log.errorf("Unable to compile fragment shader: {}", color_fragment_shader_src);
        return false;
    }

    result.shader = gl.CreateProgram();
    gl.AttachShader(result.shader, vertexShader);
    gl.AttachShader(result.shader, fragmentShader);
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
    gl.BufferData(gl.ARRAY_BUFFER, VERTEX_BUFFER_SIZE * size_of(Color_Vertex_Data), nil, gl.DYNAMIC_DRAW);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, result.elementBuffer);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, 0, size_of(Color_Vertex_Data), nil);
    gl.VertexAttribPointer(1, 4, gl.FLOAT, 0, size_of(Color_Vertex_Data), rawptr(uintptr(size_of(vec2))));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    return true;
}

push_mesh_data :: proc(render_buffer: ^Render_Buffer($T), vertex: []T, index: []u32)
{
    start_index := cast(u32) len(render_buffer.vertex);
    for v in vertex
    {
        append(&render_buffer.vertex, v);
    }

    for i in index
    {
        append(&render_buffer.index, start_index + i);
    }
}

clear_render_buffer :: proc(render_buffer: ^Render_Buffer($T))
{
    clear(&render_buffer.index);
    clear(&render_buffer.vertex);
}

render_buffer_content :: proc(render_buffer : ^Render_System($T), camera: ^Camera)
{
    vertex_count := len(render_buffer.vertex);
    index_count := len(render_buffer.index);
    gl.BindVertexArray(render_buffer.render_state.vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, render_buffer.render_state.vbo);
    
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) vertex_count * size_of(Color_Vertex_Data), &render_buffer.vertex[0]);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_buffer.render_state.elementBuffer);
    gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) index_count * size_of(u32), &render_buffer.index[0]);
    gl.BindVertexArray(0);

    gl.UseProgram(render_buffer.render_state.shader);
    gl.Uniform3f(render_buffer.render_state.camPosZoomAttrib, camera.pos.x, camera.pos.y, camera.zoom);
    gl.Uniform2f(render_buffer.render_state.screenSizeAttrib, render_buffer.screen_size.x, render_buffer.screen_size.y);

    gl.BindVertexArray(render_buffer.render_state.vao);
    gl.DrawElements(gl.TRIANGLES, cast(i32) index_count, gl.UNSIGNED_INT, nil);
    gl.BindVertexArray(0);
    gl.UseProgram(0);
}

camera_to_world :: proc(camera : ^Camera, render_system: ^Render_System(Color_Vertex_Data), pos: [2]i32) -> [2]f32
{
    return [2]f32
    {
        cast(f32)pos.x + camera.pos.x - render_system.screen_size.x / 2,
        -cast(f32)pos.y + camera.pos.y + render_system.screen_size.y / 2
    };
}