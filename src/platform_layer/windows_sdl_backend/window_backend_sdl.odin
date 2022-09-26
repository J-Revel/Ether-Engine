package windows_sdl_backend

import sdl "vendor:sdl2"
import sdl_image "vendor:sdl2/image"
import "../../input"
import "core:strings"
import "core:math/linalg"
import "core:os"
import platform_layer "../base"

/*******************************
 * COMMON PART OF PLATFORM LAYER
 * *****************************/

Window_Handle :: platform_layer.Window_Handle
File_Error :: platform_layer.File_Error

Render_Window :: struct {
    sdl_window: ^sdl.Window,
    screen_size: [2]i32,
}

windows: map[Window_Handle]Render_Window
next_window_handle: Window_Handle

key_map: map[sdl.Scancode]input.Input_Key

sdl_renderer: ^sdl.Renderer

init :: proc(screen_size: [2]i32) -> (Window_Handle, bool) {
    
    platform_layer.load_file = load_file
    platform_layer.update_events = update_events
    platform_layer.get_window_size = get_window_size
    platform_layer.get_window_raw_ptr = get_sdl_window
    platform_layer.load_font = load_font
    platform_layer.compute_text_render_buffer = compute_text_render_buffer
    platform_layer.get_font_metrics = get_font_metrics
    platform_layer.render_draw_commands = render_draw_commands
    platform_layer.gen_uid = gen_uid
    
    init_key_map()
    next_window_handle += 1
    init_err := sdl.Init(sdl.INIT_VIDEO | sdl.INIT_AUDIO)
    if init_err == 0 
    {
        // log.info("load SDL_IMAGE")
        sdl_image.Init(sdl_image.INIT_PNG)

        // render.init_font_render()

        // log.info("Setting up the window...")
        
        window := sdl.CreateWindow("Ether", 100, 100, screen_size.x, screen_size.y, sdl.WINDOW_OPENGL|sdl.WINDOW_MOUSE_FOCUS|sdl.WINDOW_SHOWN|sdl.WINDOW_RESIZABLE)
        if window == nil {
            // log.debugf("Error during window creation: %s", sdl.GetError())
            return {}, false
        }
        sdl_renderer = sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC)
        sdl.SetRenderDrawBlendMode(sdl_renderer, .BLEND)
        windows[next_window_handle] = {window, screen_size}
        return next_window_handle, true
    }
    return {}, false
}

free :: proc(window: Window_Handle) {
    sdl.DestroyWindow(windows[window].sdl_window)
    sdl_image.Quit()
    sdl.Quit()
}

update_events :: proc(window_handle: Window_Handle, using input_state: ^input.State) {
    window := windows[window_handle]
    sdl.GetWindowSize(window.sdl_window, &window.screen_size.x, &window.screen_size.y)
    mx, my : i32
    sdl.GetMouseState(&mx, &my)
    input_state.mouse_pos = {int(mx), int(my)}

    
    // Set mouse pos if window is focused
    if sdl.GetKeyboardFocus() == windows[window_handle].sdl_window {
        input_state.mouse_pos = linalg.to_int(mouse_pos)
    }
    e : sdl.Event
    for sdl.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT: {
                input_state.quit = true
            }
            case .MOUSEWHEEL: {
            }

            case .TEXTINPUT: {
                text := e.text
                input_state.text_input = strings.clone(string(cstring(&text.text[0])))
            }

            case .MOUSEBUTTONDOWN: {
                if e.button.button == 1 do input_state.key_states[.MOUSE_LEFT] = current_frame
                if e.button.button == 2 do input_state.key_states[.MOUSE_MIDDLE] = current_frame
                if e.button.button == 3 do input_state.key_states[.MOUSE_RIGHT] = current_frame
            }

            case .MOUSEBUTTONUP: {
                if e.button.button == 1 do input_state.key_states[.MOUSE_LEFT] = -current_frame
                if e.button.button == 2 do input_state.key_states[.MOUSE_MIDDLE] = -current_frame
                if e.button.button == 3 do input_state.key_states[.MOUSE_RIGHT] = -current_frame
            }

            case .KEYDOWN, .KEYUP: {
                sc := e.key.keysym.scancode
                input_key: input.Input_Key

                key, ok := key_map[sc]
                if ok {
                    input_state.key_states[key] = e.type == .KEYDOWN ? current_frame : -current_frame

                }
            }
        }
    }
}

load_file :: proc(path: string, allocator := context.allocator) -> ([]u8, File_Error) {
    data, ok := os.read_entire_file(path, allocator)
    if ok do return data, .None
    return nil, .File_Not_Found
}

init_key_map :: proc() {
    key_map[.A] = input.Input_Key.A
    key_map[.B] = input.Input_Key.B
    key_map[.C] = input.Input_Key.C
    key_map[.D] = input.Input_Key.D
    key_map[.E] = input.Input_Key.E
    key_map[.F] = input.Input_Key.F
    key_map[.G] = input.Input_Key.G
    key_map[.H] = input.Input_Key.H
    key_map[.I] = input.Input_Key.I
    key_map[.J] = input.Input_Key.J
    key_map[.K] = input.Input_Key.K
    key_map[.L] = input.Input_Key.L
    key_map[.M] = input.Input_Key.M
    key_map[.N] = input.Input_Key.N
    key_map[.O] = input.Input_Key.O
    key_map[.P] = input.Input_Key.P
    key_map[.Q] = input.Input_Key.Q
    key_map[.R] = input.Input_Key.R
    key_map[.S] = input.Input_Key.S
    key_map[.T] = input.Input_Key.T
    key_map[.U] = input.Input_Key.U
    key_map[.V] = input.Input_Key.V
    key_map[.W] = input.Input_Key.W
    key_map[.X] = input.Input_Key.X
    key_map[.Z] = input.Input_Key.Z
    key_map[.UP] = input.Input_Key.UP
    key_map[.DOWN] = input.Input_Key.DOWN
    key_map[.LEFT] = input.Input_Key.LEFT
    key_map[.RIGHT] = input.Input_Key.RIGHT
    key_map[.ESCAPE] = input.Input_Key.ESCAPE
    key_map[.RETURN] = input.Input_Key.RETURN
}

get_sdl_window :: proc(window_handle: Window_Handle) -> rawptr {
    return windows[window_handle].sdl_window
}

get_window_size :: proc(window_handle: Window_Handle) -> [2]int {
    return linalg.to_int(windows[window_handle].screen_size)
}

gen_uid :: proc(location := #caller_location, additional_index: int = 0) -> platform_layer.UID {
    to_hash := make([]byte, len(transmute([]byte)location.file_path) + size_of(i32) * 2)
    mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path))
    location_line := location.line
    mem.copy(&to_hash[len(location.file_path)], &location_line, size_of(i32))
    additional_index_cpy := additional_index
    mem.copy(&to_hash[len(location.file_path) + size_of(i32)], &additional_index_cpy, size_of(i32))
    return UID(hash.djb2(to_hash))
}