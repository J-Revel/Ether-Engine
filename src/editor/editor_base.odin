package editor

import imgui "../imgui";
import "../render"
import "core:log"

Editor_State :: struct
{
	show_demo_window: bool,
}

update_editor :: proc(editor_state: ^Editor_State, screen_size: [2]f32, texture: ^render.Texture)
{
	imgui.set_next_window_pos({screen_size.x / 2, 0}, .Always);
    imgui.set_next_window_size({screen_size.x / 2, screen_size.y}, .Always);

	imgui.begin("editor main", nil, .NoMove | .NoResize | .NoTitleBar);

    imgui.checkbox("Show Demo Window", &editor_state.show_demo_window);

	draw_list := imgui.get_window_draw_list();
	pos : imgui.Vec2;
	imgui.get_cursor_screen_pos(&pos);
	log.info(texture.texture_id);
	texture_id := imgui.Texture_ID(rawptr(uintptr(texture.texture_id)));
	imgui.draw_list_add_image(draw_list, texture_id, pos, pos + [2]f32{f32(texture.size.x), f32(texture.size.y)}, {0, 0}, {1, 1}, 0xffffffff);
	imgui.end();

    if editor_state.show_demo_window
    {
    	imgui.show_demo_window(&editor_state.show_demo_window);
    }
}