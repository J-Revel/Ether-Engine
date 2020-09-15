package input

InputDelegates: struct
{
	keyPressed: 
}

handle_input :: proc(inputState: ^InputState)
{
	for sdl.poll_event(&e) != 0 {
        #partial switch e.type {

            case .Quit:
                log.info("Got SDL_QUIT event!");
                running = false;

            case .Key_Down:
                if is_key_down(e, .Escape) {
                    qe := sdl.Event{};
                    qe.type = .Quit;
                    //sdl.push_event(&qe);
                }
                if is_key_down(e, .Tab) {
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
            }
        }
        //imsdl.process_event(e, &imgui_state.sdl_state);
        #partial switch e.type {
        }
    }
}