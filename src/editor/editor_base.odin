package editor

import imgui "../imgui";
import "../render"

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
	imgui.end();

	draw_list := imgui.get_window_draw_list();
	imgui.draw_list_add_image(draw_list, imgui.Texture_ID(&texture.texture_id), {0, 0}, {200, 200}, {0, 0}, {1, 1}, 0xffffffff);

    if editor_state.show_demo_window
    {
    	imgui.show_demo_window(&editor_state.show_demo_window);
    }
}