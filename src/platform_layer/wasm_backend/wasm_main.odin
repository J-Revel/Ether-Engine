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
import "../../util"
import platform_layer "../base"
import "core:intrinsics"

foreign import ethereal "ethereal"

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
    fmt.println("loaded webgl version", webgl_major, webgl_minor)

    success := js.add_event_listener("webgl2", .Click, nil, on_click, false)
    // fmt.println(success)
    success = js.add_window_event_listener(.Mouse_Move, nil, on_click, false)
    // fmt.println(success)
    init_text_asset_database(&text_asset_db, 200)
    load_text_asset("ui.vert", &text_asset_db)
    load_text_asset("ui.frag", &text_asset_db)
}

on_click :: proc(e: js.Event) {
    // fmt.println(e.data.mouse.screen, e.data.mouse.client, e.data.mouse.offset, e.data.mouse.page, e.data.mouse.movement)
}

Renderer :: struct {
    vao: gl.VertexArrayObject,
    vbo: gl.Buffer,
    program: gl.Program,
}

UI_Vertex_Data :: struct {
    pos: [2]f32,
    uv: [2]f32,
    // col: [4]u8,
}

MAX_PASS_CAPACITY :: 100

init_renderer :: proc() -> (renderer: Renderer, success: bool) {
    renderer.vao = gl.CreateVertexArray()
    renderer.vbo = gl.CreateBuffer()
    vertex_shader_source := []string{""}
    fragment_shader_source := []string{""}
    ok: bool
    renderer.program, ok = gl.CreateProgramFromStrings(vertex_shader_source, fragment_shader_source)
    if !ok do return renderer, false

    gl.BindVertexArray(renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(UI_Vertex_Data), 0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(UI_Vertex_Data), size_of(f32)*2)
    // gl.VertexAttribPointer(2, 4, gl.BYTE, false, sizeof(UI_Vertex_Data), sizeof(f32)*4)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
    return renderer, true
}

Text_Asset_Handle :: distinct uint

load_text_asset :: proc "contextless" (path: string, using database: ^Text_Asset_Database) -> Text_Asset_Handle {
    @(default_calling_convention="contextless")
    foreign ethereal {
        @(link_name="load_text_asset")
        _load_text_asset :: proc(asset: ^uint, path: string) ---
    }
    allocated_handle, ok := util.bit_array_allocate(allocated_bit_array)
    if !ok do return {}
    util.bit_array_set(&loaded_bit_array, allocated_handle, false)
    _load_text_asset(&allocated_handle, path)
    return Text_Asset_Handle(allocated_handle)
}

Text_Asset_Database :: struct {
    allocated_bit_array: util.Bit_Array,
    loaded_bit_array: util.Bit_Array,
    data_size: []int,
    data: []string,
}

text_asset_db: Text_Asset_Database

init_text_asset_database :: proc(using database: ^Text_Asset_Database, capacity: int) {
    database.allocated_bit_array = make(util.Bit_Array, (capacity + 31) / 32)
    database.loaded_bit_array = make(util.Bit_Array, (capacity + 31) / 32)
    database.data = make([]string, capacity)
}

@export allocate_asset_size :: proc(size: int) -> rawptr {
    context.allocator = main_allocator
    context.temp_allocator = temp_allocator
    return &make([]byte, size)[0]
}

@export on_text_asset_loaded :: proc(asset_handle: uint, text: string) {
    using text_asset_db
    context.allocator = main_allocator
    context.temp_allocator = temp_allocator
    fmt.println("ON TEXT ASSET LOADED :")
    fmt.println(asset_handle, text)
    util.bit_array_set(&loaded_bit_array, asset_handle, true)
    data[asset_handle] = text
}