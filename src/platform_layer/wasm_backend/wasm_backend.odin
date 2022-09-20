package windows_sdl_backend

import wasm "vendor:wasm/js"
import "../../input"
import "core:strings"
import "core:math/linalg"
import platform_layer "../base"

/*******************************
 * COMMON PART OF PLATFORM LAYER
 * *****************************/

Window_Handle :: platform_layer.Window_Handle
Platform_Layer :: platform_layer.Platform_Layer
File_Error :: platform_layer.File_Error

Render_Window :: struct {
}
next_handle: Window_Handle



init :: proc(screen_size: [2]i32) -> (Window_Handle, bool) {
    platform_layer.instance = new(platform_layer.Platform_Layer)
    platform_layer.instance^ = platform_layer.Platform_Layer{
        load_file = load_file,
        update_events = update_events,
        get_window_size = get_window_size,
        get_window_raw_ptr = get_sdl_window,
    }
    return next_handle, true
}

free :: proc(window: Window_Handle) {
}

update_events :: proc(window_handle: Window_Handle, using input_state: ^input.State) {
    
}

load_file :: proc(path: string, allocator := context.allocator) -> ([]u8, File_Error) {
    return nil, .File_Not_Found
}

get_sdl_window :: proc(window_handle: Window_Handle) -> rawptr {
    return nil
}

get_window_size :: proc(window_handle: Window_Handle) -> [2]int {
    return {}
}