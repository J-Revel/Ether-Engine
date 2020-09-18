package render

import "core:mem";
import "core:log";
import "core:strings";
import "core:math";

import gl "shared:odin-gl";

@(private="package")
fragmentShaderSrc :: `
#version 450
in vec4 frag_color;
in vec2 frag_pos;
layout (location = 0) out vec4 out_color;

void main()
{
    out_color = frag_color;
}
`;

@(private="package")
vertexShaderSrc :: `
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

VertexData :: struct
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

RenderBuffer :: struct
{
    vertex: [20000]VertexData,
    vertexCount: u32,
    index: [50000]u32,
    indexCount: u32,
}

Render_System :: struct
{
    screen_size: vec2,
    using buffer: RenderBuffer,
    render_state: Render_State,
}

initRenderer :: proc (result: ^Render_State) -> bool
{
    vertexShader := gl.CreateShader(gl.VERTEX_SHADER);
    fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER);
    vertexShaderText := cast(^u8)strings.clone_to_cstring(vertexShaderSrc, context.temp_allocator);
    fragmentShaderText := cast(^u8)strings.clone_to_cstring(fragmentShaderSrc, context.temp_allocator);
    gl.ShaderSource(vertexShader, 1, &vertexShaderText, nil);
    gl.ShaderSource(fragmentShader, 1, &fragmentShaderText, nil);
    gl.CompileShader(vertexShader);
    gl.CompileShader(fragmentShader);
    fragOk: i32;
    vertOk: i32;
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &vertOk);
    if vertOk != gl.TRUE {
        log.errorf("Unable to compile vertex shader: {}", vertexShaderSrc);
        return false;
    }
    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &fragOk);
    if fragOk != gl.TRUE || vertOk != gl.TRUE {
        log.errorf("Unable to compile fragment shader: {}", fragmentShaderSrc);
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
    gl.BufferData(gl.ARRAY_BUFFER, VERTEX_BUFFER_SIZE * size_of(VertexData), nil, gl.DYNAMIC_DRAW);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, result.elementBuffer);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, 0, size_of(VertexData), nil);
    gl.VertexAttribPointer(1, 4, gl.FLOAT, 0, size_of(VertexData), rawptr(uintptr(size_of(vec2))));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    return true;
}

pushMeshData :: proc(render_buffer: ^RenderBuffer, vertex: []VertexData, index: []u32)
{
    startIndex := render_buffer.vertexCount;
    for v in vertex
    {
        render_buffer.vertex[render_buffer.vertexCount] = v;
        render_buffer.vertexCount += 1;
    }

    for i in index
    {
        render_buffer.index[render_buffer.indexCount] = startIndex + i;
        render_buffer.indexCount += 1;
    }
}

clearRenderBuffer :: proc(render_buffer: ^RenderBuffer)
{
    render_buffer.indexCount = 0;
    render_buffer.vertexCount = 0;
}

renderBufferContent :: proc(render_buffer : ^Render_System, camera: ^Camera)
{
    gl.BindVertexArray(render_buffer.render_state.vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, render_buffer.render_state.vbo);
    
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) render_buffer.vertexCount * size_of(VertexData), &render_buffer.vertex);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_buffer.render_state.elementBuffer);
    gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) render_buffer.indexCount * size_of(u32), &render_buffer.index);
    gl.BindVertexArray(0);

    gl.UseProgram(render_buffer.render_state.shader);
    gl.Uniform3f(render_buffer.render_state.camPosZoomAttrib, camera.pos.x, camera.pos.y, camera.zoom);
    gl.Uniform2f(render_buffer.render_state.screenSizeAttrib, render_buffer.screen_size.x, render_buffer.screen_size.y);

    gl.BindVertexArray(render_buffer.render_state.vao);
    gl.DrawElements(gl.TRIANGLES, cast(i32) render_buffer.indexCount, gl.UNSIGNED_INT, nil);
    gl.BindVertexArray(0);
    gl.UseProgram(0);
}
