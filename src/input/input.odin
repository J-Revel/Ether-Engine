package input

import sdl "vendor:sdl2"
import runtime "core:runtime"
import "core:math/linalg"
import "core:strings"

vec2 :: [2]f32
ivec2 :: [2]int


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
    mouse_pos: ivec2,
    key_states: [Input_Key]int,
    mouse_captured: bool,
    keyboard_captured: bool,
    text_input: string,
    current_frame: int,
}

new_frame :: proc(state: ^State) {
    state.current_frame += 1
    if len(state.text_input) > 0 {
        // log.info("clear input")
    }
    state.text_input = ""
}

get_key_state :: proc(state: ^State, key: Input_Key) -> (result: Key_State)
{
	key_state := state.key_states[key]
	if key_state == state.current_frame || key_state == -state.current_frame do incl(&result, Key_State.Just_Updated)
	if key_state > 0 do incl(&result, Key_State.Down)
	return result
}

update_dt :: proc(state: ^State) {
    freq := sdl.GetPerformanceFrequency()
    curr_time := sdl.GetPerformanceCounter()
    // TODO : fill io.delta_time somewhere
    state.time = curr_time
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
