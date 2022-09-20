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
Texture_Handle :: platform_layer.Texture_Handle
Platform_Layer :: platform_layer.Platform_Layer
File_Error :: platform_layer.File_Error

next_handle: Texture_Handle



init :: proc(screen_size: [2]i32) -> (Window_Handle, bool) {
    platform_layer.instance = new(platform_layer.Platform_Layer)
    platform_layer.instance^ = platform_layer.Platform_Layer{
        load_file = load_file,
        update_events = update_events,
        get_window_size = get_window_size,
        get_window_raw_ptr = get_sdl_window,
    }
    return {}, true
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
    next_handle += 1
    // textures[next_handle] = texture
    return next_handle
}