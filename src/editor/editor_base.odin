package editor

import imgui "../imgui";
import "../render"
import "core:log"
import "core:strings"
import "../util/container"
import "core:mem"
import "core:runtime"

Editor_State :: struct
{
	show_demo_window: bool,
	sprite_editor: Sprite_Editor_State,
}

init_editor :: proc(editor_state: ^Editor_State, texture_id: container.Handle(render.Texture))
{
	editor_state.sprite_editor.texture_id = texture_id;
}

update_editor :: proc(editor_state: ^Editor_State, screen_size: [2]f32)
{
	imgui.set_next_window_pos({screen_size.x / 2, 0}, .Always);
    imgui.set_next_window_size({screen_size.x / 2, screen_size.y}, .Always);

	imgui.begin("editor main", nil, .NoMove | .NoResize | .NoTitleBar);

    imgui.checkbox("Show Demo Window", &editor_state.show_demo_window);

	update_sprite_editor(&editor_state.sprite_editor);

    if editor_state.show_demo_window
    {
    	imgui.show_demo_window(&editor_state.show_demo_window);
    }
}

Editor_Sprite_Data :: struct
{
	name: [50]u8,
	using data: render.Sprite_Data,
}

Sprite_Editor_State :: struct
{
	texture_id: container.Handle(render.Texture),
	sprites_data: [dynamic]Editor_Sprite_Data,
	scale: f32,

	drag_start_pos: [2]f32,
	dragging: bool,

	edit_sprite_index: int,
}

bytes_to_string :: proc(data: []u8) -> string
{
	length := runtime.cstring_len(transmute(cstring)&data[0]);
	return transmute(string)mem.Raw_String{&data[0], length};
}

update_sprite_editor :: proc(using editor_state: ^Sprite_Editor_State)
{
	imgui.slider_float("scale", &scale, 0.01, 2);
	for sprite_data, index in &sprites_data
	{
		imgui.push_id(i32(index));
		if imgui.input_text("name", sprite_data.name[:])
		{

		}
		if edit_sprite_index != index + 1 && imgui.button("Edit")
		{
			edit_sprite_index = index + 1;
		}

		imgui.pop_id();
	}
	if edit_sprite_index > 0 && imgui.button("Stop Edition") do edit_sprite_index = 0;
	draw_list := imgui.get_window_draw_list();
	pos : imgui.Vec2;
	imgui.get_cursor_screen_pos(&pos);


	texture := container.handle_get(texture_id);
	texture_raw_id := imgui.Texture_ID(rawptr(uintptr(texture.texture_id)));
	texture_size : [2]f32 = {f32(texture.size.x), f32(texture.size.y)};
	imgui.draw_list_add_image(draw_list, texture_raw_id, pos, pos + texture_size * scale, {0, 0}, {1, 1}, 0xffffffff);

	for sprite_data, index in sprites_data
	{
		color :u32 = 0xff0000ff;
		if edit_sprite_index == index + 1 do color = 0xff00ffff; 
		clip_top_left := pos + texture_size * scale * sprite_data.clip.pos;
		clip_bottom_right := pos + texture_size * scale * (sprite_data.clip.pos + sprite_data.clip.size);
		clip_size := texture_size * scale * sprite_data.clip.size;
		imgui.draw_list_add_rect(draw_list, clip_top_left, clip_bottom_right, color);
		imgui.draw_list_add_circle(draw_list, clip_top_left + clip_size * sprite_data.anchor, 2, color);
	}
	
	io := imgui.get_io();
	relative_mouse_pos := (io.mouse_pos - pos) / texture_size / scale;

	if io.want_capture_mouse && render.is_in_rect({pos, texture_size}, io.mouse_pos)
	{
		if edit_sprite_index <= 0
		{
			if io.mouse_down[0]
			{
				if !dragging
				{
					dragging = true;
					drag_start_pos = relative_mouse_pos;
				}
			}
			else
			{
				if dragging
				{
					dragging = false;
					drag_rect := render.Sprite_Data{{0.5, 0.5}, {drag_start_pos, relative_mouse_pos - drag_start_pos}};
					append(&sprites_data, Editor_Sprite_Data{{}, drag_rect});
				}
			}
		}
		else
		{
			clip := &(sprites_data[edit_sprite_index - 1].clip);
			if io.mouse_down[0]
			{
				clip := &(sprites_data[edit_sprite_index - 1].clip);
				bottom_right_corner := clip.pos + clip.size;
				clip.pos = relative_mouse_pos;
				clip.size = bottom_right_corner - clip.pos;

			}
			if io.mouse_down[2]
			{
				clip.size = relative_mouse_pos - clip.pos;
			}
		}
	}
	imgui.end();
}