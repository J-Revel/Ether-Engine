package editor

import imgui "../imgui";
import "../render"
import "core:log"
import "core:strings"
import "../util/container"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"

init_editor :: proc(editor_state: ^Editor_State, texture_id: container.Handle(render.Texture))
{
	editor_state.sprite_editor.texture_id = texture_id;
	editor_state.sprite_editor.scale = 1;
}

update_editor :: proc(editor_state: ^Editor_State, screen_size: [2]f32)
{
	imgui.set_next_window_pos({screen_size.x / 2, 0}, .Always);
    imgui.set_next_window_size({screen_size.x / 2, screen_size.y}, .Always);

	imgui.begin("editor main", nil, .NoMove | .NoResize | .NoTitleBar);

    imgui.checkbox("Show Demo Window", &editor_state.show_demo_window);

	update_sprite_editor(&editor_state.sprite_editor, screen_size);

    if editor_state.show_demo_window
    {
    	imgui.show_demo_window(&editor_state.show_demo_window);
    }
}

bytes_to_string :: proc(data: []u8) -> string
{
	length := runtime.cstring_len(transmute(cstring)&data[0]);
	return transmute(string)mem.Raw_String{&data[0], length};
}

save_sprites :: proc(output_path: string, using editor_state: ^Sprite_Editor_State)
{
	texture: ^render.Texture = container.handle_get(texture_id);
	temp_sprite_table : container.Table(render.Sprite);
	container.table_init(&temp_sprite_table, uint(len(sprites_data)), context.temp_allocator);

	for sprite_data in &sprites_data
	{
		sprite: render.Sprite = {
			texture_id, 
			bytes_to_string(sprite_data.name[:]),
			sprite_data.data
		};
		container.table_add(&temp_sprite_table, sprite);
	}
	//render.save_sprites_to_file_editor(output_path, );
}

update_sprite_editor :: proc(using editor_state: ^Sprite_Editor_State, screen_size: [2]f32)
{
	io := imgui.get_io();
	imgui.slider_float("scale", &scale, 0.01, 2);
	for sprite_data, index in &sprites_data
	{
		imgui.push_id(fmt.tprintf("sprite_%d", index));
		imgui.columns(4);
		imgui.input_text("name", sprite_data.name[:]);
		imgui.next_column();
		
		imgui.next_column();
		imgui.slider_float2("anchor", &sprite_data.anchor, 0, 1);
		imgui.next_column();

		if imgui.button("Remove")
		{
			for i in index..<(len(sprites_data) - 1)
			{
				sprites_data[i] = sprites_data[i + 1];
			}
			pop(&sprites_data);
		}
		imgui.next_column();

		imgui.pop_id();
	}

	draw_list := imgui.get_window_draw_list();
	texture := container.handle_get(texture_id);
	texture_raw_id := imgui.Texture_ID(rawptr(uintptr(texture.texture_id)));
	texture_size : [2]f32 = {f32(texture.size.x), f32(texture.size.y)};

	imgui.columns(1);
	
	if(imgui.button("Save"))
	{
		sprite_names := make([]string, len(sprites_data), context.temp_allocator);
		sprite_save_data := make([]render.Sprite_Data, len(sprites_data), context.temp_allocator);
		for sprite_editor_data, index in sprites_data
		{
			sprite_names[index] = bytes_to_string(sprite_editor_data.name);
			sprite_save_data[index] = sprite_editor_data.data;
		}
		output_path, was_allocation := strings.replace(texture.path, ".png", ".meta", -1, context.temp_allocator);
		render.save_sprites_to_file_editor(output_path, sprite_names, sprite_save_data);
	}
	if(imgui.button("Load"))
	{
		input_path, was_allocation := strings.replace(texture.path, ".png", ".meta", -1, context.temp_allocator);
		in_names, in_data, ok := render.load_sprites_from_file_editor(input_path, context.temp_allocator);
		if ok
		{
			clear(&sprites_data); // TODO : memory leak
			for sprite_name, index in &in_names
			{
				new_sprite := Editor_Sprite_Data{data = in_data[index]};
				name_copy := strings.clone(sprite_name, context.temp_allocator);
				new_sprite.name = make([]byte, 50, context.allocator); // TODO : memory leak
				mem.copy(&new_sprite.name[0], &(transmute([]byte)name_copy)[0], len(name_copy));
				append(&sprites_data, new_sprite);
			}
		}
	}

	imgui.set_next_window_pos({0, 0}, .Always);
    imgui.set_next_window_size({screen_size.x / 2, screen_size.y}, .Always);
	imgui.begin("Sprite Editor", nil, .NoMove | .NoResize | .NoTitleBar | .HorizontalScrollbar);
	pos : imgui.Vec2;
	draw_list = imgui.get_window_draw_list();
	imgui.get_cursor_screen_pos(&pos);
	imgui.draw_list_add_rect_filled(draw_list, pos, pos + texture_size * scale, 0xaa000000);
	imgui.draw_list_add_image(draw_list, texture_raw_id, pos, pos + texture_size * scale, {0, 0}, {1, 1}, 0xffffffff);

	draw_sprite_gizmos(editor_state, draw_list, pos);
	size := texture_size * scale + {20, 20};
	imgui.invisible_button("sprite_editor", size);

	sprite_editor_hovered := false;

    if (imgui.is_item_hovered())
    {
    	sprite_editor_hovered = true;
    }		
	imgui.end();


	if io.want_capture_mouse
	{
		relative_mouse_pos := (io.mouse_pos - pos) / texture_size / scale;
		switch tool_data.tool_type
		{
			case .None:
			{
				update_none_sprite_tool(editor_state, relative_mouse_pos, sprite_editor_hovered);

			}
			case .Move:
			{
				update_move_sprite_tool(editor_state, relative_mouse_pos, sprite_editor_hovered);
			}
			case .Resize:
			{
				update_resize_sprite_tool(editor_state, relative_mouse_pos, sprite_editor_hovered);
			}
			case .Move_Anchor:
			{
				update_move_anchor_sprite_tool(editor_state, relative_mouse_pos, sprite_editor_hovered);
			}
		}
	}
	imgui.end();
}

update_none_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, relative_mouse_pos: [2]f32, editor_hovered: bool)
{
	io := imgui.get_io();
	if !editor_hovered do return;
	for sprite_data, index in sprites_data
	{
		clip_top_left := sprite_data.clip.pos;
		clip_bottom_right := (sprite_data.clip.pos + sprite_data.clip.size);
		clip_size := sprite_data.clip.size;
		anchor_pos := clip_top_left + clip_size * sprite_data.anchor;
		sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners({clip_top_left, clip_size}, relative_mouse_pos, 0.01);
		sprites_data[index].render_color = sprite_hovered ? 0xffff00ff : 0xff0000ff;
		anchor_hovered := linalg.length(anchor_pos - relative_mouse_pos) < 0.01;
		sprites_data[index].anchor_render_color = anchor_hovered ? 0xffffffff : sprites_data[index].render_color;

		for i in 0..<4 do sprites_data[index].render_corner_colors[i] = 0;
		#partial switch h_edit
		{
			case .Min:
			{
				sprites_data[index].render_corner_colors[0] = 0xffffffff;
			}
			case .Max:
			{

				sprites_data[index].render_corner_colors[1] = 0xffffffff;
			}
		}
		#partial switch v_edit
		{
			case .Min:
			{
				sprites_data[index].render_corner_colors[2] = 0xffffffff;
			}
			case .Max:
			{

				sprites_data[index].render_corner_colors[3] = 0xffffffff;
			}
		}

		if io.mouse_down[0] && sprite_hovered
		{
			if anchor_hovered
			{
				tool_data.tool_type = .Move_Anchor;
			}
			else if v_edit == .None && h_edit == .None
			{
				tool_data.tool_type = .Move;
			}
			else
			{
				tool_data.tool_type = .Resize;
			}
			tool_data.last_mouse_pos = relative_mouse_pos;
			tool_data.edited_sprite_index = index;
			tool_data.edit_sprite_h_corner = h_edit;
			tool_data.edit_sprite_v_corner = v_edit;
		}
	}
	if io.mouse_down[2]
	{
		tool_data.tool_type = .Resize;
		tool_data.edited_sprite_index = len(sprites_data);
		tool_data.edit_sprite_h_corner = .Max;
		tool_data.edit_sprite_v_corner = .Max;

		drag_start_pos = relative_mouse_pos;
		drag_rect := render.Sprite_Data{{0.5, 0.5}, {drag_start_pos, relative_mouse_pos - drag_start_pos}};
		default_sprite_name := "default";
		sprite_name_data := make([]byte, 50, context.allocator);
		copy(sprite_name_data, default_sprite_name);
		sprite_name_data[len(default_sprite_name)] = 0;
		append(&sprites_data, Editor_Sprite_Data{sprite_name_data, drag_rect, 0xff0000ff, 0xff0000ff, {}});
	}
	tool_data.last_mouse_pos = relative_mouse_pos;
}

update_move_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, relative_mouse_pos: [2]f32, editor_hovered: bool)
{
	io := imgui.get_io();
	offset := relative_mouse_pos - tool_data.last_mouse_pos;
	tool_data.last_mouse_pos = relative_mouse_pos;
	sprites_data[tool_data.edited_sprite_index].clip.pos += offset;
	if !io.mouse_down[0]
	{
		tool_data.tool_type = .None;
	}
}

update_resize_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, relative_mouse_pos: [2]f32, editor_hovered: bool)
{
	io := imgui.get_io();
	offset := relative_mouse_pos - tool_data.last_mouse_pos;
	#partial switch tool_data.edit_sprite_h_corner
	{
		case .Min:
		{
			sprites_data[tool_data.edited_sprite_index].clip.pos.x += offset.x;
			sprites_data[tool_data.edited_sprite_index].clip.size.x -= offset.x;
		}
		case .Max:
		{
			sprites_data[tool_data.edited_sprite_index].clip.size.x += offset.x;
		}

	}
	#partial switch tool_data.edit_sprite_v_corner
	{
		case .Min:
		{
			sprites_data[tool_data.edited_sprite_index].clip.pos.y += offset.y;
			sprites_data[tool_data.edited_sprite_index].clip.size.y -= offset.y;
		}
		case .Max:
		{
			sprites_data[tool_data.edited_sprite_index].clip.size.y += offset.y;
		}

	}
	//sprites_data[tool_data.edited_sprite_index].clip.size += relative_mouse_pos - tool_data.last_mouse_pos;
	tool_data.last_mouse_pos = relative_mouse_pos;
	if !io.mouse_down[0] && !io.mouse_down[2]
	{
		tool_data.tool_type = .None;
	}
}

update_move_anchor_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, relative_mouse_pos: [2]f32, editor_hovered: bool)
{
	io := imgui.get_io();
	offset := relative_mouse_pos - tool_data.last_mouse_pos;
	sprite_index := tool_data.edited_sprite_index;
	sprite_data := &sprites_data[sprite_index];
	clip_top_left := sprite_data.clip.pos;
	clip_bottom_right := (sprite_data.clip.pos + sprite_data.clip.size);
	clip_size := sprite_data.clip.size;
	sprite_data.anchor += offset / clip_size;
	tool_data.last_mouse_pos = relative_mouse_pos;
	if !io.mouse_down[0] && !io.mouse_down[2]
	{
		tool_data.tool_type = .None;
	}
}

compute_sprite_edit_corners :: proc(sprite_rect: render.Rect, mouse_pos: [2]f32, precision: f32) -> (out_hovered: bool, out_h: Sprite_Edit_Corner, out_v: Sprite_Edit_Corner)
{
	out_hovered = (mouse_pos.x > sprite_rect.pos.x - precision && mouse_pos.y > sprite_rect.pos.y - precision
		&& mouse_pos.x < sprite_rect.pos.x + sprite_rect.size.x + precision && mouse_pos.y < sprite_rect.pos.y + sprite_rect.size.y + precision);
	if !out_hovered do return;
	if abs(sprite_rect.pos.x - mouse_pos.x) < precision
	{
		out_h = .Min;
	}
	else if abs(sprite_rect.pos.x + sprite_rect.size.x - mouse_pos.x) < precision
	{
		out_h = .Max;
	}
	if abs(sprite_rect.pos.y - mouse_pos.y) < precision
	{
		out_v = .Min;
	}
	else if abs(sprite_rect.pos.y + sprite_rect.size.y - mouse_pos.y) < precision
	{
		out_v = .Max;
	}
	return;
}

draw_sprite_gizmos :: proc(using editor_state: ^Sprite_Editor_State, draw_list: ^imgui.Draw_List, editor_pos: [2]f32)
{
	texture := container.handle_get(texture_id);
	texture_raw_id := imgui.Texture_ID(rawptr(uintptr(texture.texture_id)));
	texture_size : [2]f32 = {f32(texture.size.x), f32(texture.size.y)};
	for sprite_data, index in sprites_data
	{
		clip_size := sprite_data.clip.size * scale * texture_size;
		clip_pos := sprite_data.clip.pos * scale * texture_size;
		clip_top_left := editor_pos + clip_pos;
		clip_bottom_right := editor_pos + clip_pos + clip_size;
		imgui.draw_list_add_rect(draw_list, clip_top_left, clip_bottom_right, sprite_data.render_color);

		imgui.draw_list_add_circle(draw_list, clip_top_left + clip_size * sprite_data.anchor, 2, sprite_data.anchor_render_color);
		if sprite_data.render_corner_colors[0] != 0
		{
			imgui.draw_list_add_rect(draw_list, clip_top_left, {clip_top_left.x, clip_bottom_right.y}, sprite_data.render_corner_colors[0]);
		}
		if sprite_data.render_corner_colors[1] != 0
		{
			imgui.draw_list_add_rect(draw_list, {clip_bottom_right.x, clip_top_left.y}, clip_bottom_right, sprite_data.render_corner_colors[1]);
		}
		if sprite_data.render_corner_colors[2] != 0
		{
			imgui.draw_list_add_rect(draw_list, clip_top_left, {clip_bottom_right.x, clip_top_left.y}, sprite_data.render_corner_colors[2]);
		}
		if sprite_data.render_corner_colors[3] != 0
		{
			imgui.draw_list_add_rect(draw_list, {clip_top_left.x, clip_bottom_right.y}, clip_bottom_right, sprite_data.render_corner_colors[3]);
		}
	}
}