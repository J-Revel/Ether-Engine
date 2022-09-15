package input

import sdl "vendor:sdl2"
import "core:log"
import runtime "core:runtime"
import "core:math/linalg"
import "core:strings"

vec2 :: [2]f32
ivec2 :: [2]int

current_frame: int = 1

Key_State_Flags :: enum
{
	Down,
	Just_Updated,
}

Key_State :: bit_set[Key_State_Flags]

Key_State_Pressed :: Key_State{.Down, .Just_Updated}
Key_State_Released :: Key_State{.Just_Updated}
Key_State_Down :: Key_State{.Down}
Key_State_Up :: Key_State{}

State :: struct {
    time: u64,
    quit: bool,
    mouse_states: [3]int,
    mouse_pos: ivec2,
    key_states: [512]int,
    mouse_captured: bool,
    keyboard_captured: bool,
    text_input: string,
}

new_frame :: proc(state: ^State) {
    current_frame += 1
    if len(state.text_input) > 0 {
        log.info("clear input")
    }
    state.text_input = ""
}

get_key_state :: proc(state: ^State, key: sdl.Scancode) -> (result: Key_State)
{
	key_state := state.key_states[key]
	if key_state == current_frame || key_state == -current_frame do incl(&result, Key_State.Just_Updated)
	if key_state > 0 do incl(&result, Key_State.Down)
	return result
}

get_mouse_state :: proc(state: ^State, button: int) -> (result: Key_State)
{
	mouse_state := state.mouse_states[button]
	if mouse_state == current_frame || mouse_state == -current_frame do incl(&result, Key_State.Just_Updated)
	if mouse_state > 0 do incl(&result, Key_State.Down)
	return result
}

process_events :: proc(state: ^State) {
    e : sdl.Event
    for sdl.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT: {
                state.quit = true
            }
            case .MOUSEWHEEL: {
            }

            case .TEXTINPUT: {
                text := e.text
                state.text_input = strings.clone(string(cstring(&text.text[0])))
            }

            case .MOUSEBUTTONDOWN: {
                if e.button.button == 1 do state.mouse_states[0] = current_frame
                if e.button.button == 2 do state.mouse_states[1] = current_frame
                if e.button.button == 3 do state.mouse_states[2] = current_frame
            }

            case .MOUSEBUTTONUP: {
                if e.button.button == 1 do state.mouse_states[0] = -current_frame
                if e.button.button == 2 do state.mouse_states[1] = -current_frame
                if e.button.button == 3 do state.mouse_states[2] = -current_frame
            }

            case .KEYDOWN, .KEYUP: {
                sc := e.key.keysym.scancode
                state.key_states[sc] = e.type == .KEYDOWN ? current_frame : -current_frame
            }
        }
    }
}

update_dt :: proc(state: ^State) {
    freq := sdl.GetPerformanceFrequency()
    curr_time := sdl.GetPerformanceCounter()
    // TODO : fill io.delta_time somewhere
    state.time = curr_time
}

update_mouse :: proc(state: ^State, window: ^sdl.Window) {
    mx, my: i32
    sdl.GetMouseState(&mx, &my)
    
    // Set mouse pos if window is focused
    if sdl.GetKeyboardFocus() == window {
        state.mouse_pos = [2]int{int(mx), int(my)}
    }
}

set_clipboard_text :: proc "c"(user_data : rawptr, text : cstring) {
    context = runtime.default_context()
    sdl.SetClipboardText(text)
}

get_clipboard_text :: proc "c"(user_data : rawptr) -> cstring {
    context = runtime.default_context()
    @static text_ptr: cstring
    if text_ptr != nil {
        sdl.free(cast(^byte)text_ptr)
    }
    text_ptr = sdl.GetClipboardText()

    return text_ptr
}
