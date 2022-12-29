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

log :: proc(args: ..any) {
    js.log(fmt.tprint(args=args))
}

log_json :: proc(args: ..any) {
    b: strings.Builder
    for arg in args {
        strings.builder_init(&b)
        json.marshal_to_builder(&b, arg, {})
        js.log(strings.to_string(b))
    }
}

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
    log_json(current_tick)
}

main :: proc() {
    page_allocator := js.page_allocator()
    color = {1, 0, 1}
    
    data, error := js.page_alloc(100)
    if error != nil {
        js.log("Error during arena memory allocation")
        return
    }

    mem.arena_init(&alloc_arena, data)
    main_allocator = mem.arena_allocator(&alloc_arena)
    context.allocator = main_allocator

    data, error = js.page_alloc(100)
    mem.arena_init(&temp_arena, data)
    temp_allocator = mem.arena_allocator(&temp_arena)
    context.temp_allocator = temp_allocator
    log("x", "This is a test", intrinsics.wasm_memory_size(0))
    gl.CreateCurrentContextById("webgl2", {})
    gl.ClearColor(1, 0, 0, 1)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    testVec: vec2 = {12, 50}
    webgl_major, webgl_minor: i32
    gl.GetWebGLVersion(&webgl_major, &webgl_minor)
    log(webgl_major, webgl_minor)
    log_json(main_allocator)
}