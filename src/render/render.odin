package render

import "core:mem";
import "core:log";
import "core:strings";

import gl  "shared:odin-gl";

@(private="package")
fragmentShaderSrc :: `
#version 450
in vec4 frag_color;
layout (location = 0) out vec4 out_color;
void main()
{
    out_color = Frag_Color;
}
`;

@(private="package")
vertexShaderSrc :: `
#version 450
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 color;
out vec4 frag_color;
void main()
{
    frag_color = color;
    gl_Position = vec4(pos.xy,0,1);
}
`;

RendererState :: struct
{
    shader: u32,

    pos_attrib: i32,
    color_attrib: i32,

    vao: u32,
    vbo: u32,
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

    result.pos_attrib = gl.GetUniformLocation(result.shader, "pos");
    result.color_attrib = gl.GetUniformLocation(result.shader, "color");
    
    gl.GenBuffers(1, &result.vao);
    gl.GenBuffers(1, &result.vbo);
    return true;
}

