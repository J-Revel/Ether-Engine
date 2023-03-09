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

File_Asset_Database :: struct {
    allocated_bit_array: util.Bit_Array,
    loaded_bit_array: util.Bit_Array,
    error_bit_array: util.Bit_Array,
    assets: [][]u8, // Assets are allocated directly with the provided allocators
    allocators: []mem.Allocator,
}

file_asset_db: File_Asset_Database

init_backend :: proc(file_asset_capacity: int = 50) {
    init_file_asset_database(&file_asset_db, file_asset_capacity)
}

init_file_asset_database :: proc(using database: ^File_Asset_Database, asset_count_capacity: int) {
    database.allocated_bit_array = make(util.Bit_Array, (asset_count_capacity + 31) / 32)
    database.loaded_bit_array = make(util.Bit_Array, (asset_count_capacity + 31) / 32)
    database.error_bit_array = make(util.Bit_Array, (asset_count_capacity + 31) / 32)
    database.assets = make([][]u8, asset_count_capacity)
    database.allocators = make([]mem.Allocator, asset_count_capacity)
}

free :: proc(window: Window_Handle) {

}

update_events :: proc(window_handle: Window_Handle, using input_state: ^input.State) {

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

@export allocate_file_asset_size :: proc(file_handle: platform_layer.File_Handle, size: int) -> rawptr {
    using file_asset_db
    assets[int(file_handle)] = make([]byte, size, allocators[int(file_handle)])
    return &assets[int(file_handle)][0]
}

@export on_binary_asset_loaded :: proc(asset_handle: uint) {
    using file_asset_db
    fmt.println("LOADED ", asset_handle)
    util.bit_array_set(&loaded_bit_array, asset_handle, true)
}

get_file_data :: proc(file_handle: File_Handle) -> ([]u8, File_State) {
    using file_asset_db
    assert(util.bit_array_get(&allocated_bit_array, int(file_handle)))
    if util.bit_array_get(&error_bit_array, int(file_handle)) {
        return {}, .Error
    }
    else if util.bit_array_get(&loaded_bit_array, int(file_handle)) {
        return assets[file_handle], .Loaded
    }

    return {}, .Pending
}


unload_file :: proc(file_handle: File_Handle) {

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
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos), c.uv_pos})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + {c.size.x, 0}), c.uv_pos + {c.uv_size.x, 0}})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + c.size), c.uv_pos + c.uv_size})

                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos), c.uv_pos})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + c.size), c.uv_pos + c.uv_size})
                append(&vertex_buffer, UI_Vertex_Data{linalg.to_f32(c.pos + {0, c.size.y}), c.uv_pos + {0, c.uv_size.y}})
            case platform_layer.Glyph_Command:
        }
    }
    fmt.println(vertex_buffer)
}

get_font_metrics :: proc(platform_layer.Font_Handle) -> platform_layer.Font_Metrics {
    return {}
}

gen_uid :: proc(location := #caller_location, additional_index: int = 0) -> platform_layer.UID {
    to_hash: [500]byte 
    mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path))
    return platform_layer.UID(hash.djb2(to_hash[:]))
}