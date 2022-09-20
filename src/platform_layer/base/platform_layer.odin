package platform_layer

import "../../input"

/*******************************
 * COMMON PART OF PLATFORM LAYER
     * *****************************/

Window_Handle :: distinct int

Update_Event_Proc :: proc(window: Window_Handle, using input_state: ^input.State)
Load_File_Proc :: proc(file_path: string, allocator := context.allocator) -> ([]u8, File_Error)
Get_Window_Size_Proc :: proc(window: Window_Handle) -> [2]int
Get_Window_Raw_Ptr_Proc :: proc(window: Window_Handle) -> rawptr

Platform_Layer :: struct {
    update_events: Update_Event_Proc,
    load_file: Load_File_Proc,
    get_window_size: Get_Window_Size_Proc,
    get_window_raw_ptr: Get_Window_Raw_Ptr_Proc,
}

File_Error :: enum {
    None,
    File_Not_Found,
}

instance: ^Platform_Layer
