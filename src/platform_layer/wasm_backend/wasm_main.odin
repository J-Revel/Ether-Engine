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
start_tick : time.Tick
previous_tick: time.Tick

text_asset_db: Text_Asset_Database
shader_asset_db: Shader_Asset_Database
pending_shader_assets: []Shader_Loading_Asset
test_renderer: Renderer

test_vertex: []UI_Vertex_Data = {
    {{-1, -1}, {-1, -1}},
    {{1, -1}, {1, -1}},
    {{1, 1}, {1, -1}}
}

main_shader: Shader_Asset_Handle

@export step :: proc()
{
    context.allocator = main_allocator
    context.temp_allocator = temp_allocator
    update_shader_asset_database(&shader_asset_db, &text_asset_db)
    current_tick := time.tick_now()
    t += f32(time.duration_seconds(time.tick_diff(previous_tick, current_tick)))
    previous_tick = current_tick
    gl.ClearColor((math.cos(t) + 1)/2 * color.x, color.y, color.z, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    render_data(&test_renderer, test_vertex)
    if !first_frame {
        first_frame = true
    }
}

main :: proc() {
    previous_tick = time.tick_now()
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

    success := js.add_event_listener("webgl2", .Mouse_Move, nil, on_click, false)
    // fmt.println(success)
    // success = js.add_window_event_listener(.Mouse_Move, nil, on_click, false)
    // fmt.println(success)
    init_text_asset_database(&text_asset_db, 200)
    init_shader_asset_database(&shader_asset_db, 50)
    main_shader = load_shader_asset(&shader_asset_db, &text_asset_db, "webgl/ui.vert", "webgl/ui.frag", )
    // load_text_asset(&text_asset_db, "ui.vert")
    // load_text_asset(&text_asset_db, "ui.frag")
    pending_shader_assets = make([]Shader_Loading_Asset, 50, main_allocator)
    ok: bool
    test_renderer, ok = init_renderer()
    if !ok {
        fmt.println("Could not create renderer")
    }

}

on_click :: proc(e: js.Event) {
    canvas_rect := js.get_bounding_client_rect("webgl2")
    // fmt.println(canvas_rect)
    // fmt.println(e.data.mouse.client)
    mouse_pos : [2]f64 = {(f64(e.data.mouse.client.y) ) / canvas_rect.width * 2 - 1, 1 - 2 * (f64(e.data.mouse.offset.x)) / canvas_rect.height}
    test_vertex = {
        {{-1, -1}, {-1, -1}},
        {{f32(mouse_pos.x), -1}, {1, -1}},
        {{f32(mouse_pos.x), f32(mouse_pos.y)}, {1, 1}}
    }
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

    gl.BindVertexArray(renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(UI_Vertex_Data) * 500, nil, gl.DYNAMIC_DRAW)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(UI_Vertex_Data), 0)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(UI_Vertex_Data), size_of(f32)*2)
    // gl.VertexAttribPointer(2, 4, gl.BYTE, false, sizeof(UI_Vertex_Data), sizeof(f32)*4)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
    return renderer, true
}

render_data :: proc(renderer: ^Renderer, to_render: []UI_Vertex_Data) {
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    gl.UseProgram(shader_asset_db.data[main_shader])
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(UI_Vertex_Data) * len(to_render), &to_render[0])
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(renderer.vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 3)
    gl.BindVertexArray(0)
}

Text_Asset_Handle :: distinct uint

load_text_asset :: proc "contextless" (using database: ^Text_Asset_Database, path: string) -> Text_Asset_Handle {
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
    data: []string,
}

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
    util.bit_array_set(&loaded_bit_array, asset_handle, true)
    data[asset_handle] = text
}

Shader_Loading_Asset :: struct {
    vertex_asset: Text_Asset_Handle,
    fragment_asset: Text_Asset_Handle,
}

Shader_Asset_Handle :: distinct uint

Shader_Asset_Data :: struct {
    program: gl.Program,
    fragment_text_asset, vertex_text_asset: Text_Asset_Handle,
}

Shader_Asset_Database :: struct {
    allocated_bit_array: util.Bit_Array,
    loaded_bit_array: util.Bit_Array,
    loading_data: []Shader_Loading_Asset,
    data: []gl.Program,
}

init_shader_asset_database :: proc(using database: ^Shader_Asset_Database, capacity: int) {
    allocated_bit_array = make(util.Bit_Array, (capacity + 31) / 32)
    loaded_bit_array = make(util.Bit_Array, (capacity + 31) / 32)
    data = make([]gl.Program, capacity)
    loading_data = make([]Shader_Loading_Asset, capacity)
}

load_shader_asset :: proc(
        using database: ^Shader_Asset_Database, 
        text_asset_db: ^Text_Asset_Database, 
        vertex_src_path, fragment_src_path: string, 
    ) -> Shader_Asset_Handle {
    
    vertex_asset := load_text_asset(text_asset_db, vertex_src_path)
    fragment_asset := load_text_asset(text_asset_db, fragment_src_path)
    allocated_handle, ok := util.bit_array_allocate(allocated_bit_array)
    if !ok do return {}
    util.bit_array_set(&loaded_bit_array, allocated_handle, false)
    loading_data[allocated_handle] = {
        vertex_asset = vertex_asset,
        fragment_asset = fragment_asset,
    }
    return Shader_Asset_Handle(allocated_handle)
}

update_shader_asset_database :: proc(using database: ^Shader_Asset_Database, text_database: ^Text_Asset_Database) {
    for i in 0..<len(loaded_bit_array) {
        for j in 0..<32 {
            shader_asset_index := i*32 + j
            if util.bit_array_get(&allocated_bit_array, shader_asset_index) && !util.bit_array_get(&loaded_bit_array, shader_asset_index) {
                fragment_src_asset := loading_data[shader_asset_index].fragment_asset
                vertex_src_asset := loading_data[shader_asset_index].vertex_asset
                fragment_loaded := util.bit_array_get(&text_database.loaded_bit_array, int(fragment_src_asset))
                vertex_loaded := util.bit_array_get(&text_database.loaded_bit_array, int(vertex_src_asset))
                if fragment_loaded && vertex_loaded {
                    fmt.println(text_database.data[fragment_src_asset])
                    fmt.println(text_database.data[vertex_src_asset])
                    vertex_shader_source := []string{text_database.data[vertex_src_asset]}
                    fragment_shader_source := []string{text_database.data[fragment_src_asset]}
                    ok: bool
                    data[shader_asset_index], ok = gl.CreateProgramFromStrings(vertex_shader_source, fragment_shader_source)
                    util.bit_array_set(&loaded_bit_array, uint(shader_asset_index), true)
                }
            }
        }
    }
}