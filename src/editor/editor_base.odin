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

import "../geometry"

init_editor :: proc(using editor_state: ^Editor_State)
{
	container.table_init(&editor_state.sprite_editor.loaded_textures, 10);
	sprite_editor.scale = 1;
	sprite_editor.theme.sprite_normal, _ = render.hex_color_to_u32("e74c3c");
	sprite_editor.theme.sprite_hovered, _ = render.hex_color_to_u32("f71c1c");
	sprite_editor.theme.sprite_selected, _ = render.hex_color_to_u32("2980b9");
	sprite_editor.theme.sprite_gizmo, _ = render.hex_color_to_u32("bdc3c7");
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
    imgui.end();
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

	if imgui.button("Open Texture")
    {
    	init_folder_display("resources/textures", &folder_display_state);
    	editor_state.searching_file = true;
    }

    if editor_state.searching_file
    {
    	path, was_allocated := folder_display(&folder_display_state, context.temp_allocator);
    	if len(path) > 0
    	{
    		if strings.has_suffix(path, ".png")
    		{
    			if texture_id.id > 0
    			{
    				render.unload_texture(container.handle_get(texture_id));
    			}
    			searching_file = false;
				path_copy := strings.clone(path, context.allocator);
    			texture := render.load_texture(path_copy);
    			texture_id, _ = container.table_add(&loaded_textures, texture);
				load_sprites_for_texture(editor_state, texture.path);
    		}
    		folder_display_state.current_path = path;
    		update_folder_display(&folder_display_state);
    	}
    }
    if texture_id.id > 0
    {

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
		imgui.text(texture.path);
		
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
			load_sprites_for_texture(editor_state, texture.path);
		}

		editor_pos : [2]f32 = {0, 0};
		editor_size : [2]f32 = {screen_size.x / 2, screen_size.y};
		imgui.set_next_window_pos(editor_pos, .Always);
	    imgui.set_next_window_size(editor_size, .Always);
		imgui.begin("Sprite Editor", nil, .NoMove | .NoResize | .NoTitleBar | .NoScrollbar);

		draw_list = imgui.get_window_draw_list();
		pos: [2]f32;
		imgui.get_cursor_screen_pos(&pos);
		editor_center_pos : [2]f32 = editor_pos + editor_size / 2;
		
		render_data : Sprite_Editor_Render_Data = 
		{
			texture_rect = {
				editor_center_pos - texture_size * scale / 2 - drag_offset, 
				texture_size * scale
			},
			editor_rect = {
				editor_pos,
				editor_size
			},
			mouse_pos = io.mouse_pos,
			mouse_offset = last_mouse_pos - io.mouse_pos,
		};

		imgui.draw_list_add_rect_filled(draw_list, render_data.texture_rect.pos, render_data.texture_rect.pos + render_data.texture_rect.size, 0xaa000000);
		imgui.draw_list_add_image(draw_list, texture_raw_id, render_data.texture_rect.pos, render_data.texture_rect.pos + render_data.texture_rect.size, {0, 0}, {1, 1}, 0xffffffff);

		draw_sprite_gizmos(editor_state, draw_list, render_data);
		
		// Todo : Right editor size calculation to be integrable inside any ui
		size := texture_size * scale + {20, 20};
		imgui.invisible_button("sprite_editor", size);

		sprite_editor_hovered := true;


		last_mouse_pos = io.mouse_pos;

		if io.want_capture_mouse
		{
			switch tool_data.tool_type
			{
				case .None:
				{
					update_none_sprite_tool(editor_state, render_data);
				}
				case .Scroll:
				{
					update_scroll_sprite_tool(editor_state, render_data);
				}
				case .Selected:
				{
					update_selected_sprite_tool(editor_state, render_data);
				}
				case .Move:
				{
					update_move_sprite_tool(editor_state, render_data);
				}
				case .Resize:
				{
					update_resize_sprite_tool(editor_state, render_data);
				}
				case .Move_Anchor:
				{
					update_move_anchor_sprite_tool(editor_state, render_data);
				}
			}
		}
		imgui.end();
    }
}

get_relative_pos :: proc(rect: geometry.Rect, pos: [2]f32) -> [2]f32
{
	return (pos - rect.pos) / rect.size;
}


update_scroll_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	drag_offset += mouse_offset;
	relative_mouse_pos := get_relative_pos(texture_rect, mouse_pos);
	tool_data.last_mouse_pos = relative_mouse_pos;

	draw_list := imgui.get_window_draw_list();
	for sprite_data in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		render_sprite_rect(draw_list, sprite_rect, theme.sprite_normal);

	}
	if mouse_offset.x != 0 || mouse_offset.y != 0
	{
		tool_data.moved = true;
	}
	if !io.mouse_down[0]
	{
		tool_data.tool_type = .None;
		log.info(tool_data.moved);
		if !tool_data.moved
		{
			for sprite_data, index in sprites_data
			{
				clip_top_left := sprite_data.clip.pos;
				clip_bottom_right := (sprite_data.clip.pos + sprite_data.clip.size);
				clip_size := sprite_data.clip.size;
				anchor_pos := clip_top_left + clip_size * sprite_data.anchor;
				sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners({clip_top_left, clip_size}, relative_mouse_pos, 0.01);
				if sprite_hovered
				{
					tool_data.edited_sprite_index = index;
					tool_data.tool_type = .Selected;
					return;
				}
			}
		}
	}
}

update_none_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	draw_list := imgui.get_window_draw_list();
	relative_mouse_pos := get_relative_pos(texture_rect, mouse_pos);
	editor_hovered := geometry.is_in_rect(editor_rect, mouse_pos);
	for sprite_data, index in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners(sprite_rect, mouse_pos, 5);
		

		render_sprite_rect(draw_list, sprite_rect, sprite_hovered ? theme.sprite_hovered : theme.sprite_normal);
		
	}
	if editor_hovered
	{
		if io.mouse_down[0]
		{
			tool_data.tool_type = .Scroll;
			tool_data.last_tool = .None;
			tool_data.moved = false;
			tool_data.last_mouse_pos = relative_mouse_pos;
		}
		if io.mouse_down[2]
		{
			tool_data.tool_type = .Resize;
			tool_data.last_tool = .None;
			tool_data.edited_sprite_index = len(sprites_data);
			tool_data.edit_sprite_h_corner = .Max;
			tool_data.edit_sprite_v_corner = .Max;

			drag_start_pos = relative_mouse_pos;
			drag_rect := render.Sprite_Data{{0.5, 0.5}, {drag_start_pos, relative_mouse_pos - drag_start_pos}};
			default_sprite_name := "default";
			sprite_name_data := make([]byte, 50, context.allocator);
			copy(sprite_name_data, default_sprite_name);
			sprite_name_data[len(default_sprite_name)] = 0;
			append(&sprites_data, Editor_Sprite_Data{sprite_name_data, drag_rect, {}});
		}
		scale += io.mouse_wheel / 10;
	}
	tool_data.last_mouse_pos = relative_mouse_pos;
}

update_selected_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	editor_hovered := geometry.is_in_rect(editor_rect, mouse_pos);
	sprite_index := tool_data.edited_sprite_index;
	sprite_data := sprites_data[sprite_index]; 
	clip_top_left := sprite_data.clip.pos;
	clip_bottom_right := (sprite_data.clip.pos + sprite_data.clip.size);
	clip_size := sprite_data.clip.size;
	anchor_pos := clip_top_left + clip_size * sprite_data.anchor;

	relative_mouse_pos := get_relative_pos(texture_rect, mouse_pos);
	sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners({clip_top_left, clip_size}, relative_mouse_pos, 0.01);
	sprites_data[sprite_index].render_color = editor_hovered && sprite_hovered ? 0xffff88ff : 0xff0088ff;
	anchor_hovered := linalg.length(anchor_pos - relative_mouse_pos) < 0.01;
	tool_data.last_tool = .Selected;

	draw_list := imgui.get_window_draw_list();

	sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
	render_sprite_rect(draw_list, sprite_rect, theme.sprite_selected);
	if editor_hovered
	{
		#partial switch h_edit
		{
			case .Min:
			{
				render_sprite_corner(draw_list, sprite_rect, .Left, theme.sprite_gizmo);
			}
			case .Max:
			{

				render_sprite_corner(draw_list, sprite_rect, .Right, theme.sprite_gizmo);
			}
		}
		#partial switch v_edit
		{
			case .Min:
			{
				render_sprite_corner(draw_list, sprite_rect, .Up, theme.sprite_gizmo);
			}
			case .Max:
			{
				render_sprite_corner(draw_list, sprite_rect, .Down, theme.sprite_gizmo);
			}
		}

		if io.mouse_down[0]
		{
			if sprite_hovered
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
				tool_data.edited_sprite_index = sprite_index;
				tool_data.edit_sprite_h_corner = h_edit;
				tool_data.edit_sprite_v_corner = v_edit;
			}
			else
			{
				tool_data.tool_type = .Scroll;
				tool_data.last_tool = .None;
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
			append(&sprites_data, Editor_Sprite_Data{sprite_name_data, drag_rect, {}});
		}
		scale += io.mouse_wheel / 10;
	}
	tool_data.last_mouse_pos = relative_mouse_pos;
}

update_move_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	relative_mouse_pos := get_relative_pos(texture_rect, mouse_pos);
	offset := relative_mouse_pos - tool_data.last_mouse_pos;
	tool_data.last_mouse_pos = relative_mouse_pos;
	sprites_data[tool_data.edited_sprite_index].clip.pos += offset;
	if !io.mouse_down[0]
	{
		tool_data.tool_type = .Selected;
	}

	sprite_data := sprites_data[tool_data.edited_sprite_index];
	draw_list := imgui.get_window_draw_list();
	sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
	render_sprite_rect(draw_list, sprite_rect, theme.sprite_selected);
}

update_resize_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	relative_mouse_pos := get_relative_pos(texture_rect, mouse_pos);
	offset := relative_mouse_pos - tool_data.last_mouse_pos;

	sprite_data := sprites_data[tool_data.edited_sprite_index];

	draw_list := imgui.get_window_draw_list();
	sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
	render_sprite_rect(draw_list, sprite_rect, theme.sprite_selected);
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
		tool_data.tool_type = tool_data.last_tool;
	}
}

update_move_anchor_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	relative_mouse_pos := get_relative_pos(texture_rect, mouse_pos);
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
		tool_data.tool_type = tool_data.last_tool;
	}
}

compute_sprite_edit_corners :: proc(sprite_rect: geometry.Rect, mouse_pos: [2]f32, precision: f32) -> (out_hovered: bool, out_h: Sprite_Edit_Corner, out_v: Sprite_Edit_Corner)
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

draw_sprite_gizmos :: proc(using editor_state: ^Sprite_Editor_State, draw_list: ^imgui.Draw_List, render_data: Sprite_Editor_Render_Data)
{
	texture := container.handle_get(texture_id);
	texture_raw_id := imgui.Texture_ID(rawptr(uintptr(texture.texture_id)));
	texture_size : [2]f32 = {f32(texture.size.x), f32(texture.size.y)};
	for sprite_data, index in sprites_data
	{
		clip_rect := geometry.get_sub_rect(render_data.texture_rect, sprite_data.clip);
		clip_top_left := clip_rect.pos;
		clip_bottom_right := clip_rect.pos + clip_rect.size;
		imgui.draw_list_add_circle(draw_list, clip_top_left + clip_rect.size * sprite_data.anchor, 2, theme.sprite_gizmo);
	}
}

load_sprites_for_texture :: proc(using editor_state: ^Sprite_Editor_State, path: string)
{
	input_path, was_allocation := strings.replace(path, ".png", ".meta", -1, context.temp_allocator);
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

render_sprite_rect :: proc(draw_list: ^imgui.Draw_List, rect: geometry.Rect, color: u32)
{
	imgui.draw_list_add_rect(draw_list, rect.pos, rect.pos + rect.size, color);
}

render_sprite_corner :: proc(draw_list: ^imgui.Draw_List, rect: geometry.Rect, side: Sprite_Side, color: u32)
{
	top_left := rect.pos;
	bottom_right := rect.pos + rect.size;
	switch side
	{
		case .Left:
		{
			imgui.draw_list_add_rect(draw_list, top_left, {top_left.x, bottom_right.y}, color);
		}
		case .Right:
		{
			imgui.draw_list_add_rect(draw_list, {bottom_right.x, top_left.y}, bottom_right, color);
		}
		case .Up:
		{
			imgui.draw_list_add_rect(draw_list, top_left, {bottom_right.x, top_left.y}, color);
		}
		case .Down:
		{
			imgui.draw_list_add_rect(draw_list, {top_left.x, bottom_right.y}, bottom_right, color);
		}
	}
}