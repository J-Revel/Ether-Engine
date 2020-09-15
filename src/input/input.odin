package input

import sdl "shared:odin-sdl2"
import "core:log"

Input_State :: enum
{
    Up, Down
}

vec2 :: [2]f32;

Input_Delegates :: struct
{
    quit: [dynamic]proc(),
    key_state_changed: [dynamic]proc(key: sdl.Keysym, state: Input_State) -> bool,
    button_state_changed: [dynamic]proc(button: u8, mouse_pos: vec2, state: Input_State) -> bool

}

default_delegates : Input_Delegates;

active_delegates : ^Input_Delegates = &default_delegates;

set_active_delegates :: proc(delegates : ^Input_Delegates)
{
    active_delegates = delegates;
}

reset_active_delegates :: proc()
{
    active_delegates = &default_delegates;
}

handle_input :: proc()
{
    e : sdl.Event;
	for sdl.poll_event(&e) != 0 {
        #partial switch e.type {
            case .Quit:
                for delegate in active_delegates.quit do delegate();

            case .Key_Down:
                for delegate in active_delegates.key_state_changed do delegate(e.key.keysym, .Down);
            
            case .Key_Up:
                for delegate in active_delegates.key_state_changed
                {
                    if(delegate(e.key.keysym, .Up)) do break;
                }
            case .Mouse_Button_Down:
                for delegate in active_delegates.button_state_changed
                {
                    if(delegate(e.button.button, vec2{cast(f32)e.button.x, cast(f32)e.button.y}, .Down)) do break;
                }
            case .Mouse_Button_Up:
                for delegate in active_delegates.button_state_changed
                {
                    if(delegate(e.button.button, vec2{cast(f32)e.button.x, cast(f32)e.button.y}, .Up)) do break;
                }
                /*if is_key_down(e, .Tab) {
                    //if io.want_capture_keyboard == false {
                        show_demo_window = true;
                    //}
                }
            case .Mouse_Button_Down:
            //if !io.want_capture_mouse do
                append(&buildings, building);
                mousePressed = true;
            case .Mouse_Button_Up:
            //if !io.want_capture_mouse do
                mousePressed = false;
            case .Mouse_Wheel: {
            }

            case .Text_Input: {
                //text := e.text;
                //imgui.ImGuiIO_AddInputCharactersUTF8(io, cstring(&text.text[0]));
            }*/
        }
        //imsdl.process_event(e, &imgui_state.sdl_state);
        
    }
}