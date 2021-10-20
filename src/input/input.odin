package input

import "core:log"
import runtime "core:runtime"
import "core:math/linalg"
import "vendor:sdl2"

vec2 :: [2]f32;
ivec2 ::[2]int;

current_frame: int = 1;

Key_State_Flags :: enum
{
	Down,
	Just_Updated,
}

Key_State :: bit_set[Key_State_Flags];

Key_State_Pressed :: Key_State{.Down, .Just_Updated};
Key_State_Released :: Key_State{.Just_Updated};
Key_State_Down :: Key_State{.Down};
Key_State_Up :: Key_State{};

State :: struct {
    time: u64,
    quit: bool,
    mouse_states: [3]int,
    mouse_pos: ivec2,
	mouse_offset: ivec2,
    key_states: [512]int,
    // TODO : migrate specific imgui code somewhere else
    cursor_handles: [5]^sdl2.Cursor,
    mouse_captured: bool,
    keyboard_captured: bool,
}

new_frame :: proc(state: ^State) {
    current_frame += 1;
    
}

get_key_state :: proc(state: ^State, key: sdl2.Scancode) -> (result: Key_State)
{
	key_state := state.key_states[key];
	if key_state == current_frame || key_state == -current_frame do incl(&result, Key_State.Just_Updated);
	if key_state > 0 do incl(&result, Key_State.Down);
	return result;
}

get_mouse_state :: proc(state: ^State, button: int) -> (result: Key_State)
{
	mouse_state := state.mouse_states[button];
	if mouse_state == current_frame || mouse_state == -current_frame do incl(&result, Key_State.Just_Updated);
	if mouse_state > 0 do incl(&result, Key_State.Down);
	return result;
}

process_events :: proc(state: ^State) {
    e : sdl2.Event;
    for sdl2.PollEvent(&e) != 0 {
        #partial switch e.type {
            case .QUIT: {
                state.quit = true;
            }
            case .MOUSEWHEEL: {
            }

            case .TEXTINPUT: {
                text := e.text;
            }

            case .MOUSEBUTTONDOWN: {
                if e.button.button == 1 do state.mouse_states[0] = current_frame;
                if e.button.button == 2 do state.mouse_states[1] = current_frame;
                if e.button.button == 3 do state.mouse_states[2] = current_frame;
            }

            case .MOUSEBUTTONUP: {
                if e.button.button == 1 do state.mouse_states[0] = -current_frame;
                if e.button.button == 2 do state.mouse_states[1] = -current_frame;
                if e.button.button == 3 do state.mouse_states[2] = -current_frame;
            }

            case .KEYDOWN, .KEYUP: {
                sc := e.key.keysym.scancode;
                state.key_states[sc] = e.type == .KEYDOWN? current_frame : -current_frame;
            }
        }
    }
    state.keyboard_captured = false; // TODO : handle keyboard capture
    state.mouse_captured = false; // TODO : handle mouse capture
}

update_dt :: proc(state: ^State) {
    freq := sdl2.GetPerformanceFrequency();
    curr_time := sdl2.GetPerformanceCounter();
	delta_time := state.time > 0 ? f32(f64(curr_time - state.time) / f64(freq)) : f32(1/60);
    state.time = curr_time;
}

update_mouse :: proc(state: ^State, window: ^sdl2.Window) {
    mx, my: i32;
    sdl2.GetMouseState(&mx, &my);
    
    // Set mouse pos if window is focused
    if sdl2.GetKeyboardFocus() == window {
		new_mouse_pos := [2]int{int(mx), int(my)};
		state.mouse_offset = new_mouse_pos - state.mouse_pos;
        state.mouse_pos = new_mouse_pos;
    }

	// TODO : Check if this code is still needed or not
    /*if io.config_flags & .NoMouseCursorChange != .NoMouseCursorChange {
        desired_cursor := imgui.get_mouse_cursor();
        if(io.mouse_draw_cursor || desired_cursor == .None) {
            sdl2.show_cursor(i32(sdl2.Bool.False));
        } else {
            chosen_cursor := state.cursor_handles[imgui.Mouse_Cursor.Arrow];
            if state.cursor_handles[desired_cursor] != nil {
                chosen_cursor = state.cursor_handles[desired_cursor];
            }
            sdl2.set_cursor(chosen_cursor);
            sdl2.show_cursor(i32(sdl2.Bool.True));
        }
    }*/
}

update_display_size :: proc(window: ^sdl2.Window) {
    w, h, display_h, display_w: i32;
    sdl2.GetWindowSize(window, &w, &h);
    if sdl2.GetWindowFlags(window) & u32(sdl2.WindowFlags.MINIMIZED) != 0 {
        w = 0;
        h = 0;
    }
    sdl2.GetDrawableSize(window, &display_w, &display_h);

    /*io := imgui.get_io();
    io.display_size = imgui.Vec2{f32(w), f32(h)};
    if w > 0 && h > 0 {
        io.display_framebuffer_scale = imgui.Vec2{f32(display_w / w), f32(display_h / h)};
    }*/
}

set_clipboard_text :: proc "c"(user_data : rawptr, text : cstring) {
    context = runtime.default_context();
	sdl2.set_clipboard_text(text);
}

get_clipboard_text :: proc "c"(user_data : rawptr) -> cstring {
    context = runtime.default_context();
    @static text_ptr: cstring;
    if text_ptr != nil {
        sdl2.free(cast(^byte)text_ptr);
    }
    text_ptr = sdl2.get_clipboard_text();

    return text_ptr;
}
