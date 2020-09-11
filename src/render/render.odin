package render

import "core:mem";
import "core:log";
import "core:strings";
import math "../math";

import gl "shared:odin-gl";

@(private="package")
fragmentShaderSrc :: `
#version 450
in vec4 frag_color;
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

uniform vec2 screenSize;
uniform vec3 camPosZoom;

void main()
{
    frag_color = color;
    float zoom = camPosZoom.z;
    vec2 camPos = camPosZoom.xy;
    gl_Position = vec4((pos.xy - camPos) * 2 / screenSize * camPosZoom.z,0,1);
}
`;

RendererState :: struct
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
    pos: math.v2,
    color: math.v4
}

Camera :: struct
{
    pos: math.v2,
    zoom: f32,
}

INDEX_BUFFER_SIZE :: 5000;
VERTEX_BUFFER_SIZE :: 2000;

RenderBuffer :: struct
{
    vertex: [2000]VertexData,
    vertexCount: u32,
    index: [5000]u32,
    indexCount: u32,
}

initRenderer :: proc (result: ^RendererState) -> bool
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
    gl.VertexAttribPointer(1, 4, gl.FLOAT, 0, size_of(VertexData), rawptr(uintptr(size_of(math.v2))));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    return true;
}

pushMeshData :: proc(renderBuffer: ^RenderBuffer, vertex: []VertexData, index: []u32)
{
    for v in vertex
    {
        renderBuffer.vertex[renderBuffer.vertexCount] = v;
        renderBuffer.vertexCount += 1;
    }

    for i in index
    {
        renderBuffer.index[renderBuffer.indexCount] = i;
        renderBuffer.indexCount += 1;
    }
}

renderBufferContent :: proc(renderer : ^RendererState, renderBuffer : ^RenderBuffer, camera: ^Camera, screenSize: math.v2)
{
    gl.BindVertexArray(renderer.vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo);
    
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) renderBuffer.vertexCount * size_of(VertexData), &renderBuffer.vertex);
    //gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer.elementBuffer);
    //gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) renderBuffer.indexCount * size_of(u32), &renderBuffer.index);
    gl.BindVertexArray(0);

    gl.UseProgram(renderer.shader);
    gl.Uniform3f(renderer.camPosZoomAttrib, camera.pos.x, camera.pos.y, camera.zoom);
    gl.Uniform2f(renderer.screenSizeAttrib, screenSize.x, screenSize.y);

    gl.BindVertexArray(renderer.vao);
    gl.DrawArrays(gl.TRIANGLES, 0, cast(i32) renderBuffer.vertexCount);
    gl.BindVertexArray(0);
    gl.UseProgram(0);
}
