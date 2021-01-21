package input

import sdl "shared:odin-sdl2"
import imgui "../imgui"
import "core:log"
import runtime "core:runtime"

vec2 :: [2]f32;
ivec2 ::[2]i32;

current_frame: int = 1;

Key_State :: enum {
    Up, Down, Pressed, Released
}

State :: struct {
    time: u64,
    quit: bool,
    mouse_states: [3]int,
    mouse_pos: ivec2,
    key_states: [512]int,
    // TODO : migrate specific imgui code somewhere else
    cursor_handles: [imgui.Mouse_Cursor.Count]^sdl.Cursor,
    mouse_captured: bool,
    keyboard_captured: bool,
}

setup_state :: proc(using state: ^State) {
    io := imgui.get_io();
    io.backend_platform_name = "SDL";
    io.backend_flags |= .HasMouseCursors;

    io.key_map[imgui.Key.Tab]         = i32(sdl.Scancode.Tab);
    io.key_map[imgui.Key.LeftArrow]   = i32(sdl.Scancode.Left);
    io.key_map[imgui.Key.RightArrow]  = i32(sdl.Scancode.Right);
    io.key_map[imgui.Key.UpArrow]     = i32(sdl.Scancode.Up);
    io.key_map[imgui.Key.DownArrow]   = i32(sdl.Scancode.Down);
    io.key_map[imgui.Key.PageUp]      = i32(sdl.Scancode.Page_Up);
    io.key_map[imgui.Key.PageDown]    = i32(sdl.Scancode.Page_Down);
    io.key_map[imgui.Key.Home]        = i32(sdl.Scancode.Home);
    io.key_map[imgui.Key.End]         = i32(sdl.Scancode.End);
    io.key_map[imgui.Key.Insert]      = i32(sdl.Scancode.Insert);
    io.key_map[imgui.Key.Delete]      = i32(sdl.Scancode.Delete);
    io.key_map[imgui.Key.Backspace]   = i32(sdl.Scancode.Backspace);
    io.key_map[imgui.Key.Space]       = i32(sdl.Scancode.Space);
    io.key_map[imgui.Key.Enter]       = i32(sdl.Scancode.Return);
    io.key_map[imgui.Key.Escape]      = i32(sdl.Scancode.Escape);
    io.key_map[imgui.Key.KeyPadEnter] = i32(sdl.Scancode.Kp_Enter);
    io.key_map[imgui.Key.A]           = i32(sdl.Scancode.A);
    io.key_map[imgui.Key.C]           = i32(sdl.Scancode.C);
    io.key_map[imgui.Key.V]           = i32(sdl.Scancode.V);
    io.key_map[imgui.Key.X]           = i32(sdl.Scancode.X);
    io.key_map[imgui.Key.Y]           = i32(sdl.Scancode.Y);
    io.key_map[imgui.Key.Z]           = i32(sdl.Scancode.Z);

    io.get_clipboard_text_fn = get_clipboard_text;
    io.set_clipboard_text_fn = set_clipboard_text;
    
    cursor_handles[imgui.Mouse_Cursor.Arrow]      = sdl.create_system_cursor(sdl.System_Cursor.Arrow);
    cursor_handles[imgui.Mouse_Cursor.TextInput]  = sdl.create_system_cursor(sdl.System_Cursor.IBeam);
    cursor_handles[imgui.Mouse_Cursor.ResizeAll]  = sdl.create_system_cursor(sdl.System_Cursor.Size_All);
    cursor_handles[imgui.Mouse_Cursor.ResizeNs]   = sdl.create_system_cursor(sdl.System_Cursor.Size_NS);
    cursor_handles[imgui.Mouse_Cursor.ResizeEw]   = sdl.create_system_cursor(sdl.System_Cursor.Size_WE);
    cursor_handles[imgui.Mouse_Cursor.ResizeNesw] = sdl.create_system_cursor(sdl.System_Cursor.Size_NESW);
    cursor_handles[imgui.Mouse_Cursor.ResizeNwse] = sdl.create_system_cursor(sdl.System_Cursor.Size_NWSE);
    cursor_handles[imgui.Mouse_Cursor.Hand]       = sdl.create_system_cursor(sdl.System_Cursor.Hand);
    cursor_handles[imgui.Mouse_Cursor.NotAllowed] = sdl.create_system_cursor(sdl.System_Cursor.No);
}

new_frame :: proc(state: ^State) {
    current_frame += 1;
    
}

get_key_state :: proc(state: ^State, key: sdl.Scancode) -> Key_State
{
    if state.key_states[key] == current_frame do return .Pressed;
    if state.key_states[key] == -current_frame do return .Released;
    return state.key_states[key] > 0 ? .Down : .Up;
}

get_mouse_state :: proc(state: ^State, button: int) -> Key_State
{
    if state.mouse_states[button] == current_frame do return .Pressed;
    if state.mouse_states[button] == -current_frame do return .Released;
    return (state.mouse_states[button] > 0 ? .Down : .Up);
}

process_events :: proc(state: ^State) {
    e : sdl.Event;
    io := imgui.get_io();
    for sdl.poll_event(&e) != 0 {
        #partial switch e.type {
            case .Quit: {
                state.quit = true;
            }
            case .Mouse_Wheel: {
                if e.wheel.x > 0 do io.mouse_wheel_h += 1;
                if e.wheel.x < 0 do io.mouse_wheel_h -= 1;
                if e.wheel.y > 0 do io.mouse_wheel   += 1;
                if e.wheel.y < 0 do io.mouse_wheel   -= 1;
            }

            case .Text_Input: {
                text := e.text;
                imgui.ImGuiIO_AddInputCharactersUTF8(io, cstring(&text.text[0]));
            }

            case .Mouse_Button_Down: {
                if e.button.button == 1 do state.mouse_states[0] = current_frame;
                if e.button.button == 2 do state.mouse_states[1] = current_frame;
                if e.button.button == 3 do state.mouse_states[2] = current_frame;
            }

            case .Mouse_Button_Up: {
                if e.button.button == 1 do state.mouse_states[0] = -current_frame;
                if e.button.button == 2 do state.mouse_states[1] = -current_frame;
                if e.button.button == 3 do state.mouse_states[2] = -current_frame;
            }

            case .Key_Down, .Key_Up: {
                sc := e.key.keysym.scancode;
                io.keys_down[sc] = e.type == .Key_Down;
                io.key_shift = sdl.get_mod_state() & (sdl.Keymod.LShift|sdl.Keymod.RShift) != nil;
                io.key_ctrl  = sdl.get_mod_state() & (sdl.Keymod.LCtrl|sdl.Keymod.RCtrl)   != nil;
                io.key_alt   = sdl.get_mod_state() & (sdl.Keymod.LAlt|sdl.Keymod.RAlt)     != nil;
                state.key_states[sc] = e.type == .Key_Down ? current_frame : -current_frame;
                when ODIN_OS == "windows" {
                    io.key_super = false;
                } else {
                    io.key_super = sdl.get_mod_state() & (sdl.Keymod.LGui|sdl.Keymod.RGui) != nil;
                }
            }
        }
    }
    state.keyboard_captured = io.want_capture_keyboard;
    state.mouse_captured = io.want_capture_mouse;
}

update_dt :: proc(state: ^State) {
    io := imgui.get_io();
    freq := sdl.get_performance_frequency();
    curr_time := sdl.get_performance_counter();
    // TODO : fill io.delta_time somewhere
    io.delta_time = state.time > 0 ? f32(f64(curr_time - state.time) / f64(freq)) : f32(1/60);
    state.time = curr_time;
}

get_state_values :: proc(state: Key_State) -> (down: bool, justChanged: bool)
{
    switch state
    {
        case .Up: return false, false;
        case .Down: return true, false;
        case .Pressed: return true, true;
        case .Released: return false, true;
    }
    return false, false;
}

is_down :: proc(state: Key_State) -> bool
{
    return state == Key_State.Down || state == Key_State.Pressed;
}

update_mouse :: proc(state: ^State, window: ^sdl.Window) {
    io := imgui.get_io();
    mx, my: i32;
    sdl.get_mouse_state(&mx, &my);
    io.mouse_down[0] = is_down(get_mouse_state(state, 0));
    io.mouse_down[1] = is_down(get_mouse_state(state, 2));
    io.mouse_down[2] = is_down(get_mouse_state(state, 1));
    log.info(io.mouse_down);

    // Set mouse pos if window is focused
    io.mouse_pos = imgui.Vec2{min(f32), min(f32)};
    if sdl.get_keyboard_focus() == window {
        state.mouse_pos = {mx, my};
        io.mouse_pos = imgui.Vec2{f32(mx), f32(my)};
    }

    if io.config_flags & .NoMouseCursorChange != .NoMouseCursorChange {
        desired_cursor := imgui.get_mouse_cursor();
        if(io.mouse_draw_cursor || desired_cursor == .None) {
            sdl.show_cursor(i32(sdl.Bool.False));
        } else {
            chosen_cursor := state.cursor_handles[imgui.Mouse_Cursor.Arrow];
            if state.cursor_handles[desired_cursor] != nil {
                chosen_cursor = state.cursor_handles[desired_cursor];
            }
            sdl.set_cursor(chosen_cursor);
            sdl.show_cursor(i32(sdl.Bool.True));
        }
    }
}

update_display_size :: proc(window: ^sdl.Window) {
    w, h, display_h, display_w: i32;
    sdl.get_window_size(window, &w, &h);
    if sdl.get_window_flags(window) & u32(sdl.Window_Flags.Minimized) != 0 {
        w = 0;
        h = 0;
    }
    sdl.gl_get_drawable_size(window, &display_w, &display_h);

    io := imgui.get_io();
    io.display_size = imgui.Vec2{f32(w), f32(h)};
    if w > 0 && h > 0 {
        io.display_framebuffer_scale = imgui.Vec2{f32(display_w / w), f32(display_h / h)};
    }
}

set_clipboard_text :: proc "c"(user_data : rawptr, text : cstring) {
    context = runtime.default_context();
    sdl.set_clipboard_text(text);
}

get_clipboard_text :: proc "c"(user_data : rawptr) -> cstring {
    context = runtime.default_context();
    @static text_ptr: cstring;
    if text_ptr != nil {
        sdl.free(cast(^byte)text_ptr);
    }
    text_ptr = sdl.get_clipboard_text();

    return text_ptr;
}