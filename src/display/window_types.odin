package window

import backend "backend_sdl"
import input "../input"

Render_Window :: backend.Render_Window

Init_Proc :: proc(screen_size: [2]i32) -> (Render_Window, bool)
Free_Proc :: proc(render_window: ^Render_Window)
UpdateEventProc :: proc(render_window: ^Render_Window, using input_state: ^input.State)

init : Init_Proc = backend.init
free : Free_Proc = backend.free
update_events : UpdateEventProc = backend.update_events