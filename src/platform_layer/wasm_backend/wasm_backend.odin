package windows_sdl_backend

import wasm "vendor:wasm/js"
import "../../input"
import "core:strings"
import "core:math/linalg"
import platform_layer "../base"
import "core:mem"
import "core:hash"

/*******************************
 * COMMON PART OF PLATFORM LAYER
 * *****************************/

Window_Handle :: platform_layer.Window_Handle
Texture_Handle :: platform_layer.Texture_Handle
File_Error :: platform_layer.File_Error

next_handle: Texture_Handle



init :: proc(screen_size: [2]i32) -> (Window_Handle, bool) {
    platform_layer.load_file = load_file
    platform_layer.update_events = update_events
    platform_layer.get_window_size = get_window_size
    platform_layer.get_window_raw_ptr = get_sdl_window
    platform_layer.load_texture = load_texture
    platform_layer.free_texture = free_texture
    platform_layer.load_font = load_font
    platform_layer.free_font = free_font
    platform_layer.load_font = load_font
    platform_layer.free_font = free_font
    platform_layer.get_font_metrics = get_font_metrics
    platform_layer.compute_text_render_buffer = compute_text_render_buffer
    platform_layer.render_draw_commands = render_draw_commands
    platform_layer.gen_uid = gen_uid
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

}

get_font_metrics :: proc(platform_layer.Font_Handle) -> platform_layer.Font_Metrics {
    return {}
}

gen_uid :: proc(location := #caller_location, additional_index: int = 0) -> platform_layer.UID {
    to_hash: [500]byte 
    mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path))
    return platform_layer.UID(hash.djb2(to_hash[:]))
}