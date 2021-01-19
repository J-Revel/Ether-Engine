package editor

import "../imgui";
import "../render"
import "core:log"
import "core:strings"
import "../container"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"

import "../geometry"

apply_style :: proc()
{
	style := imgui.get_style();
	colors := style.colors;

	colors[imgui.Col.Text]                   = [4]f32{0.9, 0.9, 0.9, 1};
	colors[imgui.Col.TextDisabled]           = [4]f32{0.500, 0.500, 0.500, 1.000};
	colors[imgui.Col.WindowBg]               = [4]f32{0.09, 0.09, 0.09, 1.000};
	colors[imgui.Col.ChildBg]                = [4]f32{0.280, 0.280, 0.280, 0.100};
	colors[imgui.Col.PopupBg]                = [4]f32{0.313, 0.313, 0.313, 1.000};
	colors[imgui.Col.Border]                 = [4]f32{0.266, 0.266, 0.266, 1.000};
	colors[imgui.Col.BorderShadow]           = [4]f32{0.000, 0.000, 0.000, 0.000};
	colors[imgui.Col.FrameBg]                = [4]f32{0.160, 0.160, 0.160, 1.000};
	colors[imgui.Col.FrameBgHovered]         = [4]f32{0.200, 0.200, 0.200, 1.000};
	colors[imgui.Col.FrameBgActive]          = [4]f32{0.280, 0.280, 0.280, 1.000};
	colors[imgui.Col.TitleBg]                = [4]f32{0.148, 0.148, 0.148, 1.000};
	colors[imgui.Col.TitleBgActive]          = [4]f32{0.148, 0.148, 0.148, 1.000};
	colors[imgui.Col.TitleBgCollapsed]       = [4]f32{0.148, 0.148, 0.148, 1.000};
	colors[imgui.Col.MenuBarBg]              = [4]f32{0.3, 0.3, 0.3, 1.000};
	colors[imgui.Col.ScrollbarBg]            = [4]f32{0.160, 0.160, 0.160, 1.000};
	colors[imgui.Col.ScrollbarGrab]          = [4]f32{0.277, 0.277, 0.277, 1.000};
	colors[imgui.Col.ScrollbarGrabHovered]   = [4]f32{0.300, 0.300, 0.300, 1.000};
	colors[imgui.Col.ScrollbarGrabActive]    = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.CheckMark]              = [4]f32{1.000, 1.000, 1.000, 1.000};
	colors[imgui.Col.SliderGrab]             = [4]f32{0.391, 0.391, 0.391, 1.000};
	colors[imgui.Col.SliderGrabActive]       = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.Button]                 = [4]f32{1.000, 1.000, 1.000, 0.000};
	colors[imgui.Col.ButtonHovered]          = [4]f32{1.000, 1.000, 1.000, 0.156};
	colors[imgui.Col.ButtonActive]           = [4]f32{1.000, 1.000, 1.000, 0.391};
	colors[imgui.Col.Header]                 = [4]f32{0.43, 0.353, 0.353, 1.000};
	colors[imgui.Col.HeaderHovered]          = [4]f32{0.469, 0.469, 0.469, 1.000};
	colors[imgui.Col.HeaderActive]           = [4]f32{0.469, 0.469, 0.469, 1.000};
	colors[imgui.Col.Separator]              = colors[imgui.Col.Border];
	colors[imgui.Col.SeparatorHovered]       = [4]f32{0.391, 0.391, 0.391, 1.000};
	colors[imgui.Col.SeparatorActive]        = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.ResizeGrip]             = [4]f32{1.000, 1.000, 1.000, 0.250};
	colors[imgui.Col.ResizeGripHovered]      = [4]f32{1.000, 1.000, 1.000, 0.670};
	colors[imgui.Col.ResizeGripActive]       = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.Tab]                    = [4]f32{0.098, 0.098, 0.098, 1.000};
	colors[imgui.Col.TabHovered]             = [4]f32{0.352, 0.352, 0.352, 1.000};
	colors[imgui.Col.TabActive]              = [4]f32{0.195, 0.195, 0.195, 1.000};
	colors[imgui.Col.TabUnfocused]           = [4]f32{0.098, 0.098, 0.098, 1.000};
	colors[imgui.Col.TabUnfocusedActive]     = [4]f32{0.195, 0.195, 0.195, 1.000};
	//colors[imgui.Col.DockingPreview]         = [4]f32{1.000, 0.391, 0.000, 0.781};
	//colors[imgui.Col.DockingEmptyBg]         = [4]f32{0.180, 0.180, 0.180, 1.000};
	colors[imgui.Col.PlotLines]              = [4]f32{0.469, 0.469, 0.469, 1.000};
	colors[imgui.Col.PlotLinesHovered]       = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.PlotHistogram]          = [4]f32{0.586, 0.586, 0.586, 1.000};
	colors[imgui.Col.PlotHistogramHovered]   = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.TextSelectedBg]         = [4]f32{1.000, 1.000, 1.000, 0.156};
	colors[imgui.Col.DragDropTarget]         = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.NavHighlight]           = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.NavWindowingHighlight]  = [4]f32{1.000, 0.391, 0.000, 1.000};
	colors[imgui.Col.NavWindowingDimBg]      = [4]f32{0.000, 0.000, 0.000, 0.586};
	colors[imgui.Col.ModalWindowDimBg]       = [4]f32{0.000, 0.000, 0.000, 0.586};

	style.child_rounding = 4;
	style.frame_border_size = 1;
	style.frame_rounding = 2;
	style.grab_min_size = 7;
	style.popup_rounding = 2;
	style.scrollbar_rounding = 12;
	style.scrollbar_size = 13;
	style.tab_border_size = 1;
	style.tab_rounding = 0;
	style.window_rounding = 4;
	style.colors = colors;
}

init_editor :: proc(using editor_state: ^Editor_State)
{

	container.table_init(&editor_state.sprite_editor.loaded_textures, 10);
	sprite_editor.scale = 1;
	sprite_editor.theme.sprite_normal, _ = render.hex_color_to_u32("e74c3c");
	sprite_editor.theme.sprite_hovered, _ = render.hex_color_to_u32("f71c1c");
	sprite_editor.theme.sprite_selected, _ = render.hex_color_to_u32("2980b9");
	sprite_editor.theme.sprite_gizmo, _ = render.hex_color_to_u32("bdc3c7");
	apply_style();

	sprite_editor.file_selection_data.current_path = strings.clone("resources/textures");

	init_prefab_editor(&prefab_editor);
}

update_editor :: proc(using editor_state: ^Editor_State, screen_size: [2]f32)
{
	imgui.set_next_window_pos({screen_size.x / 2, 0}, .Always);
    imgui.set_next_window_size({screen_size.x / 2, screen_size.y}, .Always);

	imgui.begin("editor main", nil, .NoMove | .NoResize | .NoTitleBar);

    imgui.checkbox("Show Demo Window", &editor_state.show_demo_window);

	update_sprite_editor(&editor_state.sprite_editor, screen_size);
    imgui.separator();
	update_prefab_editor(&prefab_editor);

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
	extensions := []string{".png"};
	search_config := File_Search_Config{"resources/textures", .Show_With_Ext, extensions, false, false, false};
	path, file_search_state := file_selector_popup("sprite_selector", "Select Sprite", search_config);

	if file_search_state == .Found
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
    if texture_id.id > 0
    {

		imgui.slider_float("scale", &scale, 0.01, 2);
		imgui.columns(4);
		draw_list := imgui.get_window_draw_list();
		for sprite_data, index in &sprites_data
		{
			imgui.begin_group();
			imgui.push_id(fmt.tprintf("sprite_%d", index));
			imgui.input_text("name", sprite_data.name[:]);
			imgui.next_column();
			if imgui.button("Select")
			{
				tool_data.tool_type = .Selected;
				tool_data.edited_sprite_index = index;
			}
			
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

			imgui.end_group();

			if tool_data.tool_type != .None && tool_data.tool_type != .Scroll && tool_data.edited_sprite_index == index
			{
				imgui.columns(1);
	            group_min, group_max : [2]f32;
	            imgui.get_item_rect_min(&group_min);
	            imgui.get_item_rect_max(&group_max);
	            imgui.draw_list_add_rect_filled(draw_list, group_min, group_max, 0x55ffffff);
	            log.info(group_min, group_max, io.mouse_pos);
				imgui.columns(4);

			}
		}

		texture := container.handle_get(texture_id);
		texture_raw_id := imgui.Texture_ID(rawptr(uintptr(texture.texture_id)));
		texture_size : [2]f32 = {f32(texture.size.x), f32(texture.size.y)};

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
		};

		imgui.draw_list_add_rect_filled(draw_list, render_data.texture_rect.pos, render_data.texture_rect.pos + render_data.texture_rect.size, 0xaa000000);
		imgui.draw_list_add_image(draw_list, texture_raw_id, render_data.texture_rect.pos, render_data.texture_rect.pos + render_data.texture_rect.size, {0, 0}, {1, 1}, 0xffffffff);

		draw_sprite_gizmos(editor_state, draw_list, render_data);
		
		// Todo : Right editor size calculation to be integrable inside any ui
		size := texture_size * scale + {20, 20};
		imgui.invisible_button("sprite_editor", size);

		sprite_editor_hovered := true;

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
		tool_data.last_mouse_pos = io.mouse_pos;
		imgui.end();
    }
}


update_scroll_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	mouse_offset := mouse_pos - tool_data.last_mouse_pos;
	drag_offset -= mouse_offset;

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
				clip_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
				sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners(clip_rect, mouse_pos, 5);
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
	editor_hovered := geometry.is_in_rect(editor_rect, mouse_pos);
	for sprite_data, index in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners(sprite_rect, mouse_pos, 5);
		

		render_sprite_rect(draw_list, sprite_rect, sprite_hovered ? theme.sprite_hovered : theme.sprite_normal);
		render_sprite_point(draw_list, sprite_rect, sprite_data.anchor, theme.sprite_normal);
	}
	if editor_hovered
	{
		if io.mouse_down[0]
		{
			tool_data.tool_type = .Scroll;
			tool_data.last_tool = .None;
			tool_data.moved = false;
		}
		if io.mouse_down[2]
		{
			tool_data.tool_type = .Resize;
			tool_data.last_tool = .None;
			tool_data.edited_sprite_index = len(sprites_data);
			tool_data.edit_sprite_h_corner = .Max;
			tool_data.edit_sprite_v_corner = .Max;

			relative_mouse_pos := geometry.get_relative_pos(texture_rect, mouse_pos);
			drag_start_pos = relative_mouse_pos;
			drag_rect := render.Sprite_Data{{0.5, 0.5}, {drag_start_pos, relative_mouse_pos - drag_start_pos}};
			default_sprite_name := "default";
			sprite_name_data := make([]byte, 50, context.allocator);
			copy(sprite_name_data, default_sprite_name);
			sprite_name_data[len(default_sprite_name)] = 0;
			append(&sprites_data, Editor_Sprite_Data{sprite_name_data, drag_rect});
		}
		scale += io.mouse_wheel / 10;
	}
}

update_selected_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	editor_hovered := geometry.is_in_rect(editor_rect, mouse_pos);
	selected_sprite_index := tool_data.edited_sprite_index;
	selected_sprite_data := sprites_data[selected_sprite_index];
	selected_sprite_rect := geometry.get_sub_rect(texture_rect, selected_sprite_data.clip);
	anchor_pos := geometry.relative_to_world(selected_sprite_rect, selected_sprite_data.anchor);

	sprite_hovered, h_edit, v_edit := compute_sprite_edit_corners(selected_sprite_rect, mouse_pos, 5);
	anchor_hovered := linalg.length(anchor_pos - mouse_pos) < 5;
	tool_data.last_tool = .Selected;

	draw_list := imgui.get_window_draw_list();

	for sprite_data, index in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		render_color := index == selected_sprite_index ? theme.sprite_selected : theme.sprite_normal;
		render_sprite_rect(draw_list, sprite_rect, render_color);
		render_sprite_point(draw_list, sprite_rect, sprite_data.anchor, render_color);
	}
	if editor_hovered
	{
		#partial switch h_edit
		{
			case .Min:
			{
				render_sprite_corner(draw_list, selected_sprite_rect, .Left, theme.sprite_gizmo);
			}
			case .Max:
			{

				render_sprite_corner(draw_list, selected_sprite_rect, .Right, theme.sprite_gizmo);
			}
		}
		#partial switch v_edit
		{
			case .Min:
			{
				render_sprite_corner(draw_list, selected_sprite_rect, .Up, theme.sprite_gizmo);
			}
			case .Max:
			{
				render_sprite_corner(draw_list, selected_sprite_rect, .Down, theme.sprite_gizmo);
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
				tool_data.edited_sprite_index = selected_sprite_index;
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

			drag_start_pos = mouse_pos;
			drag_rect := render.Sprite_Data{{0.5, 0.5}, {drag_start_pos, {0, 0}}};
			default_sprite_name := "default";
			sprite_name_data := make([]byte, 50, context.allocator);
			copy(sprite_name_data, default_sprite_name);
			sprite_name_data[len(default_sprite_name)] = 0;
			append(&sprites_data, Editor_Sprite_Data{sprite_name_data, drag_rect});
		}
		if io.mouse_wheel != 0
		{
			scale += io.mouse_wheel / 10;
		}
	}
}

update_move_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	offset := mouse_pos - tool_data.last_mouse_pos;
	sprites_data[tool_data.edited_sprite_index].clip.pos += offset / texture_rect.size;
	if !io.mouse_down[0]
	{
		tool_data.tool_type = .Selected;
	}

	draw_list := imgui.get_window_draw_list();
	selected_sprite_index := tool_data.edited_sprite_index;
	for sprite_data, index in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		render_sprite_rect(draw_list, sprite_rect, index == selected_sprite_index ? theme.sprite_selected : theme.sprite_normal);
	}
}

update_resize_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	offset := mouse_pos - tool_data.last_mouse_pos;

	sprite_data := sprites_data[tool_data.edited_sprite_index];
	selected_sprite_index := tool_data.edited_sprite_index;

	draw_list := imgui.get_window_draw_list();
	sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
	relative_offset := offset / texture_rect.size;
	log.info(relative_offset);

	for sprite_data, index in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		render_sprite_rect(draw_list, sprite_rect, index == selected_sprite_index ? theme.sprite_selected : theme.sprite_normal);
	}

	#partial switch tool_data.edit_sprite_h_corner
	{
		case .Min:
		{
			sprites_data[tool_data.edited_sprite_index].clip.pos.x += relative_offset.x;
			sprites_data[tool_data.edited_sprite_index].clip.size.x -= relative_offset.x;
		}
		case .Max:
		{
			sprites_data[tool_data.edited_sprite_index].clip.size.x += relative_offset.x;
		}

	}
	#partial switch tool_data.edit_sprite_v_corner
	{
		case .Min:
		{
			sprites_data[tool_data.edited_sprite_index].clip.pos.y += relative_offset.y;
			sprites_data[tool_data.edited_sprite_index].clip.size.y -= relative_offset.y;
		}
		case .Max:
		{
			sprites_data[tool_data.edited_sprite_index].clip.size.y += relative_offset.y;
		}

	}
	//sprites_data[tool_data.edited_sprite_index].clip.size += relative_mouse_pos - tool_data.last_mouse_pos;
	
	if !io.mouse_down[0] && !io.mouse_down[2]
	{
		tool_data.tool_type = tool_data.last_tool;
	}
}

update_move_anchor_sprite_tool :: proc(using editor_state: ^Sprite_Editor_State, using render_data: Sprite_Editor_Render_Data)
{
	io := imgui.get_io();
	offset := mouse_pos - tool_data.last_mouse_pos;
	selected_sprite_index := tool_data.edited_sprite_index;
	selected_sprite_data := &sprites_data[selected_sprite_index];
	clip_top_left := selected_sprite_data.clip.pos;
	clip_bottom_right := (selected_sprite_data.clip.pos + selected_sprite_data.clip.size);
	clip_size := selected_sprite_data.clip.size;
	selected_sprite_data.anchor += offset / texture_rect.size / clip_size;
	if !io.mouse_down[0] && !io.mouse_down[2]
	{
		tool_data.tool_type = tool_data.last_tool;
	}
	draw_list := imgui.get_window_draw_list();
	for sprite_data, index in sprites_data
	{
		sprite_rect := geometry.get_sub_rect(texture_rect, sprite_data.clip);
		render_color := index == selected_sprite_index ? theme.sprite_selected : theme.sprite_normal;
		render_sprite_rect(draw_list, sprite_rect, render_color);
		render_sprite_point(draw_list, sprite_rect, sprite_data.anchor, render_color);
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

render_sprite_point :: proc(draw_list: ^imgui.Draw_List, rect: geometry.Rect, relative_point: [2]f32, color: u32)
{
	imgui.draw_list_add_circle(draw_list, rect.pos + rect.size * relative_point, 2, color);
}

render_sprite_rect :: proc(draw_list: ^imgui.Draw_List, rect: geometry.Rect, color: u32)
{
	imgui.draw_list_add_rect(draw_list, rect.pos, rect.pos + rect.size, color);
	imgui.draw_list_add_rect_filled(draw_list, rect.pos, rect.pos + rect.size, render.color_replace_alpha(color, 50));
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