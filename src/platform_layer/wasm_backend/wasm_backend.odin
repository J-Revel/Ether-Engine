package windows_sdl_backend

import wasm "vendor:wasm/js"
import "../../input"
import "core:strings"
import "core:math/linalg"
import platform_layer "../base"
import "core:mem"
import "core:hash"
import "core:fmt"
import "core:unicode/utf8"
import js "vendor:wasm/js"
import gl "vendor:wasm/WebGL"

import "../../util"

foreign import ethereal "ethereal"

/*******************************
 * COMMON PART OF PLATFORM LAYER
 * *****************************/

Window_Handle :: platform_layer.Window_Handle
Texture_Handle :: platform_layer.Texture_Handle
File_Error :: platform_layer.File_Error
File_State :: platform_layer.File_State
File_Handle :: platform_layer.File_Handle

next_texture_handle: Texture_Handle


Renderer :: struct {
    vao: gl.VertexArrayObject,
    vbo: gl.Buffer,
}

UI_Vertex_Data :: struct {
    pos: [2]f32,
    uv: [2]f32,
    col: u32,
}


init :: proc() -> (Window_Handle, bool) {
    platform_layer.load_file = load_file
    platform_layer.update_events = update_events
    platform_layer.get_window_size = get_window_size
    platform_layer.get_window_raw_ptr = get_window
    platform_layer.load_texture = load_texture
    platform_layer.free_texture = free_texture
    platform_layer.load_font = load_font
    platform_layer.free_font = free_font
    platform_layer.get_font_metrics = get_font_metrics
    platform_layer.compute_text_render_buffer = compute_text_render_buffer
    platform_layer.render_draw_commands = render_draw_commands
    platform_layer.gen_uid = gen_uid
    return {}, true
}

File_Asset_Database :: struct {
    allocated_bit_array: util.Bit_Array,
    loaded_bit_array: util.Bit_Array,
    error_bit_array: util.Bit_Array,
    assets: [][]u8, // Assets are allocated directly with the provided allocators
    allocators: []mem.Allocator,
}

Pending_Event_Data :: struct {
    kind: js.Event_Kind,
    key: string,
}

// input_key_codes: map[i64]input.Input_Key
keyboard_key_codes: map[string]input.Input_Key

pending_event_list: [200]js.Event
pending_event_cursor := 0

file_asset_db: File_Asset_Database

imgui_renderer: Renderer
screen_size: [2]f32

init_backend :: proc(file_asset_capacity: int = 50) {
    init_file_asset_database(&file_asset_db, file_asset_capacity)
    success := js.add_event_listener("webgl2", .Mouse_Move, nil, on_input_event, false)
    success &= js.add_window_event_listener(.Key_Down, nil, on_input_event, true)
    success &= js.add_window_event_listener(.Key_Up, nil, on_input_event, true)
    success &= js.add_window_event_listener(.Mouse_Down, nil, on_input_event, true)
    success &= js.add_window_event_listener(.Mouse_Up, nil, on_input_event, true)
    success &= js.add_window_event_listener(.Key_Press, nil, on_input_event, true)
    success &= js.add_event_listener("webgl2", .Context_Menu, nil, on_input_event, true)

    // input_key_codes = map[i64]input.Input_Key{
    //     48 = .NUM0, 49 = .NUM1, 50 = .NUM2, 51 = .NUM3, 52 = .NUM4, 53 = .NUM5, 54 = .NUM6, 55 = .NUM7, 56 = .NUM8, 57 = .NUM9,
    //     65 = .A, 66 = .B,  67 = .C, 68 = .D, 69 = .E, 70 = .F, 71 = .G, 72 = .H, 73 = .I, 74 = .J, 75 = .K, 76 = .L, 77 = .M, 78 = .N, 79 = .O, 80 = .P, 81 = .Q, 82 = .R, 83 = .S, 84 = .T, 85 = .U, 86 = .V, 87 = .W, 88 = .X, 89 = .Y, 90 = .Z,
    //     96 = .NUM0, 97 = .NUM1, 98 = .NUM2, 99 = .NUM3, 100 = .NUM4, 101 = .NUM5, 102 = .NUM6, 103 = .NUM7, 104 = .NUM8, 105 = .NUM9,
    //     8 = .BACKSPACE,
    //     9 = .TAB,
    //     13 = .RETURN,
    //     16 = .LSHIFT,
    //     17 = .LCTRL,
    //     18 = .LALT,
    //     37 = .LEFT,
    //     38 = .UP,
    //     39 = .RIGHT,
    //     40 = .DOWN,

    // }
    for i in 0..<26 {
        keyboard_key_codes[fmt.aprint(args = {"Key", rune('A'+i)}, sep = "")] = input.Input_Key(int(input.Input_Key.A) + i)
    }
    for i in 1..=10 {
        keyboard_key_codes[fmt.aprint(args = {"Numpad", i%10}, sep = "")] = input.Input_Key(int(input.Input_Key.KP_1) + (i-1))
        keyboard_key_codes[fmt.aprint(args = {"Digit", i%10}, sep = "")] = input.Input_Key(int(input.Input_Key.NUM1) + (i-1))
    }

    for i in 0..<24 {
        keyboard_key_codes[fmt.aprint(args = {"F", i+1}, sep = "")] = input.Input_Key(int(input.Input_Key.F1) + i)
    }
    keyboard_key_codes["NumpadSubtract"] = .KP_MINUS
    keyboard_key_codes["NumpadAdd"] = .KP_PLUS
    keyboard_key_codes["NumpadEnter"] = .KP_ENTER
    keyboard_key_codes["NumpadMultiply"] = .KP_MULTIPLY
    keyboard_key_codes["NumpadDivide"] = .KP_DIVIDE
    keyboard_key_codes["NumpadDecimal"] = .KP_PERIOD
    keyboard_key_codes["ArrowUp"] = .UP
    keyboard_key_codes["ArrowDown"] = .DOWN
    keyboard_key_codes["ArrowLeft"] = .LEFT
    keyboard_key_codes["ArrowRight"] = .RIGHT
    keyboard_key_codes["NumLock"] = .NUMLOCK
    keyboard_key_codes["Pause"] = .PAUSE
    keyboard_key_codes["Insert"] = .INSERT
    keyboard_key_codes["Home"] = .HOME
    keyboard_key_codes["Delete"] = .DELETE
    keyboard_key_codes["End"] = .END
    keyboard_key_codes["PageDown"] = .PAGEDOWN
    keyboard_key_codes["PageUp"] = .PAGEUP
    keyboard_key_codes["PrintScreen"] = .PRINTSCREEN
    keyboard_key_codes["Space"] = .SPACE
    keyboard_key_codes["AltLeft"] = .LALT
    keyboard_key_codes["ControlLeft"] = .LCTRL
    keyboard_key_codes["AltRight"] = .RALT
    keyboard_key_codes["ControlRight"] = .RCTRL
    keyboard_key_codes["Tab"] = .TAB
    keyboard_key_codes["Escape"] = .ESCAPE

    ok: bool
    imgui_renderer, ok = init_renderer()
    if !ok {
        fmt.println("ERROR INITIALIZING IMGUI RENDERER")
    }
    draw_text("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
}

init_file_asset_database :: proc(using database: ^File_Asset_Database, asset_count_capacity: int) {
    database.allocated_bit_array = make(util.Bit_Array, (asset_count_capacity + 31) / 32)
    database.loaded_bit_array = make(util.Bit_Array, (asset_count_capacity + 31) / 32)
    database.error_bit_array = make(util.Bit_Array, (asset_count_capacity + 31) / 32)
    database.assets = make([][]u8, asset_count_capacity)
    database.allocators = make([]mem.Allocator, asset_count_capacity)
}

on_input_event :: proc(e: js.Event) -> bool {
    
    pending_event_list[pending_event_cursor] = e
    result := false
    if e.kind == .Key_Down || e.kind == .Key_Press || e.kind == .Key_Up {
        key_name := js.read_key_code(&pending_event_list[pending_event_cursor])
        if key_name != "F12" && key_name != "F5" {
            result = true
        }
    }
    if(e.kind == .Context_Menu)
    {
        result = true;
    }
    pending_event_cursor += 1
    return result
}


free :: proc(window: Window_Handle) {

}

update_events :: proc(window_handle: Window_Handle, using input_state: ^input.State) {
    current_frame += 1
    canvas_rect := js.get_bounding_client_rect("webgl2")
    button_map : map[i16]input.Input_Key = {
        0 = .MOUSE_LEFT,
        1 = .MOUSE_MIDDLE,
        2 = .MOUSE_RIGHT,
    }
    for i in 0..<pending_event_cursor {
        e := pending_event_list[i]
        #partial switch e.kind {
            case .Mouse_Move:
                input_state.mouse_pos = {int(e.data.mouse.offset.x), int(e.data.mouse.offset.y)}
                mouse_pos : [2]f64 = {(f64(e.data.mouse.offset.x) ) / canvas_rect.width * 2 - 1, 1 - 2 * (f64(e.data.mouse.offset.y)) / canvas_rect.height}
                
            case .Key_Down:
                key_code := js.read_key_code(&e)
                if key_code in keyboard_key_codes{
                    key_states[keyboard_key_codes[key_code]] = current_frame
                }
                else {
                    fmt.println("Unregister key event :", js.read_key_code(&e))
                }
            case .Key_Up:
                if js.read_key_code(&e) in keyboard_key_codes{
                    key_states[keyboard_key_codes[js.read_key_code(&e)]] = -current_frame
                }
                else {
                    fmt.println("Unregister key event :", js.read_key_code(&e))
                }
            case .Key_Press:
                // fmt.println("PRESS", e.key.key, e.key.code);
                // fmt.println("INPUT", rune(e.key.charCode))
            case .Mouse_Down:
                if e.mouse.button in button_map {
                    key_states[button_map[e.mouse.button]] = current_frame
                }
            case .Mouse_Up:
                if e.mouse.button in button_map {
                    key_states[button_map[e.mouse.button]] = -current_frame
                }
        }
    }
    pending_event_cursor = 0
}

load_file :: proc(path: string, allocator := context.allocator) -> platform_layer.File_Handle {
    using file_asset_db

    @(default_calling_convention="contextless")
    foreign ethereal {
        @(link_name="load_binary_asset")
        _load_binary_asset :: proc(asset: ^u64, path: string) ---
    }

    file_handle, ok := util.bit_array_allocate(allocated_bit_array)
    if ok {
        util.bit_array_set(&loaded_bit_array, file_handle, false)
        wasm_file_handle : u64 = u64(file_handle)
        _load_binary_asset(&wasm_file_handle, path)
        allocators[file_handle] = allocator
        return platform_layer.File_Handle(file_handle)
    }
    return 0
}

draw_text :: proc(text: string, allocator := context.allocator) {
    using file_asset_db

    @(default_calling_convention="contextless")
    foreign ethereal {
        @(link_name="draw_text")
        _draw_text :: proc(text: string) ---
    }
    _draw_text(text)
}


free_file :: proc(file_handle: File_Handle, allocator := context.allocator) {
    using file_asset_db
    assert(util.bit_array_get(&allocated_bit_array, uint(file_handle)))
    util.bit_array_set(&allocated_bit_array, uint(file_handle), false)
    util.bit_array_set(&loaded_bit_array, uint(file_handle), false)
    delete(assets[int(uint(file_handle))], allocator)
}

@export allocate_file_asset_size :: proc(file_handle: platform_layer.File_Handle, size: int) -> rawptr {
    using file_asset_db
    assets[int(file_handle)] = make([]byte, size, allocators[int(file_handle)])
    return &assets[int(file_handle)][0]
}

@export on_binary_asset_loaded :: proc(asset_handle: uint) {
    using file_asset_db
    util.bit_array_set(&loaded_bit_array, asset_handle, true)
}

get_file_data :: proc(file_handle: File_Handle) -> ([]u8, File_State) {
    using file_asset_db
    assert(util.bit_array_get(&allocated_bit_array, uint(file_handle)))
    if util.bit_array_get(&error_bit_array, uint(file_handle)) {
        return {}, .Error
    }
    else if util.bit_array_get(&loaded_bit_array, uint(file_handle)) {
        return assets[file_handle], .Loaded
    }

    return {}, .Pending
}

get_window :: proc(window_handle: Window_Handle) -> rawptr {
    return nil
}

get_window_size :: proc(window_handle: Window_Handle) -> [2]int {
    canvas_rect := js.get_bounding_client_rect("webgl2")
    return {int(canvas_rect.width), int(canvas_rect.height)}
}

load_texture :: proc(file_path: string, allocator := context.allocator) -> platform_layer.Texture_Handle {
    
    // pixel_format: sdl.PixelFormatEnum  = .RGB888
    // rgba_texture_data := make([]u8, texture_data.size.x * texture_data.size.y * 3)
    // for y in 0..<texture_data.size.y {
    //     for x in 0..<texture_data.size.x {
    //         i := x + y * (texture_data.size.x)
    //         rgba_texture_data[i * 3 + 0] = 0
    //         rgba_texture_data[i * 3 + 1] = u8(y * 255 / texture_data.size.y)
    //         rgba_texture_data[i * 3 + 2] = u8(x * 255 / texture_data.size.x)
    //     }
    // }
    // if texture == nil {
    // }
    next_texture_handle += 1
    // textures[next_handle] = texture
    return next_texture_handle
}

free_texture :: proc(texture_handle: platform_layer.Texture_Handle) {

}

load_font :: proc(file_path: string, allocator := context.allocator) -> platform_layer.Font_Handle {
    return {}
}

free_font :: proc(texture_handle: platform_layer.Texture_Handle)
{

}

get_font_metric :: proc(font_handle: platform_layer.Font_Handle) -> platform_layer.Font_Metrics {
    return {}
}

compute_text_render_buffer :: proc(text: string, theme: ^platform_layer.Text_Theme, allocator := context.allocator) -> platform_layer.Text_Render_Buffer{
    return  {}
}

render_draw_commands :: proc(draw_list: ^platform_layer.Command_List) {
    vertex_buffer: [dynamic]UI_Vertex_Data
    for render_command in draw_list.commands {
        switch c in render_command {
            case platform_layer.Rect_Command:
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos), c.uv_pos, c.color})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + {c.size.x, 0}), c.uv_pos + {c.uv_size.x, 0}, c.color})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + c.size), c.uv_pos + c.uv_size, c.color})

                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos), c.uv_pos, c.color})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + c.size), c.uv_pos + c.uv_size, c.color})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + {0, c.size.y}), c.uv_pos + {0, c.uv_size.y}, c.color})
            case platform_layer.Glyph_Command:
        }
    }
    render_data(&imgui_renderer, vertex_buffer[:])
}

render_data :: proc(renderer: ^Renderer, to_render: []UI_Vertex_Data) {
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    if bind_shader(&shader_asset_db, main_shader, screen_size) {
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(UI_Vertex_Data) * len(to_render), &to_render[0])
        gl.BindBuffer(gl.ARRAY_BUFFER, 0)
        gl.BindVertexArray(renderer.vao)
        gl.DrawArrays(gl.TRIANGLES, 0, len(to_render))
    }
    gl.BindVertexArray(0)
}

get_font_metrics :: proc(platform_layer.Font_Handle) -> platform_layer.Font_Metrics {
    return {}
}

gen_uid :: proc(location := #caller_location, additional_index: int = 0) -> platform_layer.UID {
    to_hash: [500]byte 
    mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path))
    return platform_layer.UID(hash.djb2(to_hash[:]))
}
