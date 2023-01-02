package windows_sdl_backend

import "core:mem"
import "core:strings"
import "core:runtime"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:fmt"
import "core:time"
import "core:encoding/json"
import js "vendor:wasm/js"
import gl "vendor:wasm/WebGL"

import "../../input"
import "../../imgui"
import platform_layer "../base"
import "core:intrinsics"


DESIRED_GL_MAJOR_VERSION :: 4
DESIRED_GL_MINOR_VERSION :: 5
FRAME_SAMPLE_COUNT :: 10

default_screen_size :: [2]i32{1280, 720}


running := true

vec2 :: [2]f32
ivec2 :: [2]i32

t : f32 = 0
main_allocator: mem.Allocator
temp_allocator: mem.Allocator

alloc_arena, temp_arena: mem.Arena
color: [3]f32
first_frame: bool

@export step :: proc()
{
    context.allocator = main_allocator
    context.temp_allocator = temp_allocator
    current_tick := time.tick_now()
    t += 0.01
    gl.ClearColor((math.cos(t) + 1)/2 * color.x, color.y, color.z, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    if !first_frame {
        first_frame = true
    }
}

main :: proc() {
    page_allocator := js.page_allocator()
    color = {1, 0, 1}
    
    data, error := js.page_alloc(100)
    if error != nil {
        fmt.println("Error during arena memory allocation")
        return
    }

    mem.arena_init(&alloc_arena, data)
    main_allocator = mem.arena_allocator(&alloc_arena)
    context.allocator = main_allocator

    data, error = js.page_alloc(100)
    mem.arena_init(&temp_arena, data)
    temp_allocator = mem.arena_allocator(&temp_arena)
    context.temp_allocator = temp_allocator
    gl.CreateCurrentContextById("webgl2", {})
    gl.ClearColor(1, 0, 0, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    testVec: vec2 = {12, 50}
    webgl_major, webgl_minor: i32
    gl.GetWebGLVersion(&webgl_major, &webgl_minor)
    fmt.println(webgl_major, webgl_minor)
    fmt.println("This is a test")

    success := js.add_event_listener("webgl2", .Click, nil, on_click, false)
    fmt.println(success)
    success = js.add_window_event_listener(.Mouse_Move, nil, on_click, false)
    fmt.println(success)
}

on_click :: proc(e: js.Event) {
    fmt.println(e.data.mouse.screen, e.data.mouse.client, e.data.mouse.offset, e.data.mouse.page, e.data.mouse.movement)
}

Renderer :: struct {
    vao: gl.VertexArrayObject,
    vbo: gl.Buffer,
    program: gl.Program,
}

vertex_shader_source := "
#version 330 core
layout (location = 0) in vec2 in_pos;
layout (location = 1) in vec2 in_uv;

out vec2 uv;

uniform vec2 screenSize;

void main()
{
    vec2 pos = in_pos / screenSize * 2 - 1;
    uv = in_uv;
    gl_Position = vec4(pos.x, - pos.y, 0, 1);
}
"
fragment_shader_source := "
#version 330 core

uniform vec4 color;
in vec2 uv;

out vec4 out_color;
uniform sampler2D tex;

void main()
{
    out_color = color * texture(tex, uv);
}

"

UI_Vertex_Data :: struct {
    pos: [2]f32,
    uv: [2]f32,
    // col: [4]u8,
}

MAX_PASS_CAPACITY :: 100

init_renderer :: proc(renderer: ^Renderer) {
    renderer.vao = gl.CreateVertexArray()
    renderer.vbo = gl.CreateBuffer()
    renderer.program = CreateProgramFromStrings(vertex_shader_source, fragment_shader_source)
    gl.BindVertexArray(renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, sizeof(UI_Vertex_Data), 0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, sizeof(UI_Vertex_Data), sizeof(f32)*2)
    // gl.VertexAttribPointer(2, 4, gl.BYTE, false, sizeof(UI_Vertex_Data), sizeof(f32)*4)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}