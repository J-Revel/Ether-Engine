package ui

import "core:log"
import "core:hash"
import "core:math/linalg"
import "core:math"
import "core:runtime"
import "core:mem"
import "core:strings"
import "core:fmt"

import "../input"
import "../container"
import "../render"
import "../util"

join_rects :: proc(A: util.Rect, B: util.Rect) -> (result: util.Rect)
{
	if A.size.x == 0
	{
		result.size.x = B.size.x;
		result.pos.x = B.pos.x;
	}
	else if B.size.x == 0
	{
		result.size.x = A.size.x;
		result.pos.x = B.pos.x;
	}
	else
	{
		result.pos.x = min(A.pos.x, B.pos.x);
		max_x := max(A.pos.x + A.size.x, B.pos.x + B.size.x);
		result.size.x = max_x - result.pos.x;
	}
	if A.size.y == 0
	{
		result.size.y = B.size.y;
		result.pos.y = B.pos.y;
	}
	else if B.size.y == 0
	{
		result.size.y = A.size.y;
		result.pos.y = B.pos.y;
	}
	else
	{
		result.pos.y = min(A.pos.y, B.pos.y);
		max_y := max(A.pos.y + A.size.y, B.pos.y + B.size.y);
		result.size.y = max_y - result.pos.y;
	}
	return result;
}

simple_padding :: proc(value: f32) -> Padding
{
	return Padding{[2]f32{value, value}, [2]f32{value, value}};
}

init_ctx :: proc(ui_ctx: ^UI_Context, sprite_database: ^render.Sprite_Database, font: ^render.Font)
{
	ui_ctx.sprite_table = &sprite_database.sprites;
	ui_ctx.current_font = font;
	render.init_font_atlas(&sprite_database.textures, &ui_ctx.font_atlas); 
	ui_ctx.editor_config.line_height = int(ui_ctx.current_font.line_height) + 4;
	init_renderer(&ui_ctx.renderer);

	ui_ctx.current_theme = {
		window = {
			fill_color = render.rgb(100, 100, 100),
		},
		button = {
			default_theme = {
				fill_color = render.rgb(255, 255, 0),
				border_color = render.rgb(0, 0, 0),
				border_thickness = 2,
				corner_radius = 1,
			},
			hovered_theme = {
				fill_color = render.rgb(0, 255, 0),
				border_color = render.rgb(0, 0, 0),
				border_thickness = 5,
				corner_radius = 0.5,
			},
			clicked_theme = {
				fill_color = render.rgb(255, 255, 255),
				border_color = render.rgb(0, 0, 0),
				border_thickness = 1,
				corner_radius = 0.3,
			},
			corner_radius_unit = Unit.Ratio,
		},
	};
	log.info(ui_ctx.current_theme);
}

update_input_state :: proc(ui_ctx: ^UI_Context, input_state: ^input.State)
{
	using ui_ctx.input_state;
	last_cursor_pos = cursor_pos;
	cursor_pos = linalg.to_f32(input_state.mouse_pos);
	cursor_offset := cursor_pos - last_cursor_pos; 
	switch cursor_state 
	{
		case .Normal:
			if input.Key_State_Flags.Down in input.get_mouse_state(input_state, 0)
			{
				if ui_ctx.elements_under_cursor[.Press] == 0 && ui_ctx.elements_under_cursor[.Drag] != 0
				{
					cursor_state = Cursor_Input_State.Drag;
					drag_amount = {};
					delta_drag = {};
					drag_target = ui_ctx.elements_under_cursor[Interaction_Type.Drag];
				}
				else
				{
					cursor_state = Cursor_Input_State.Press;
				}
			}
		case .Press:
			cursor_state = Cursor_Input_State.Down;
			drag_amount = {};
			delta_drag = {};
		case .Down:
			drag_amount += cursor_offset;
			delta_drag = cursor_offset;
			max_down_distance: f32 = 10;
			if linalg.vector_length2(drag_amount) > max_down_distance * max_down_distance
			{
				cursor_state = Cursor_Input_State.Drag;
				drag_amount = {};
				delta_drag = {};
				drag_target = ui_ctx.elements_under_cursor[Interaction_Type.Drag];
			}
			else if input.Key_State_Flags.Down not_in input.get_mouse_state(input_state, 0)
			{
				cursor_state = Cursor_Input_State.Click_Release;
			}
		case .Drag:
			drag_amount += cursor_offset;
			delta_drag = cursor_offset;
			if input.Key_State_Flags.Down not_in input.get_mouse_state(input_state, 0)
			{
				cursor_state = Cursor_Input_State.Drag_Release;
			}
		case .Click_Release:
			cursor_state = Cursor_Input_State.Normal;
			drag_amount = {};
			delta_drag= {};
		case .Drag_Release:
			cursor_state = Cursor_Input_State.Normal;
			drag_amount = {};
			delta_drag= {};
	}
}

reset_ctx :: proc(ui_ctx: ^UI_Context, screen_size: [2]f32)
{
	clear(&ui_ctx.elements_under_cursor);
	for interaction_type, ui_id in ui_ctx.next_elements_under_cursor
	{
		ui_ctx.elements_under_cursor[interaction_type] = ui_id;
	}
	clear(&ui_ctx.next_elements_under_cursor);
	clear(&ui_ctx.layout_stack);
	base_layout := Layout {
		rect = util.Rect {
			pos = {0, 0},
			size = screen_size,
		},
		direction = [2]f32{0, 1},
	};
	push_layout_group(ui_ctx);
	add_layout_to_group(ui_ctx, base_layout);
	reset_draw_list(&ui_ctx.ui_draw_list, screen_size);
}

push_layout_group :: proc(using ui_ctx: ^UI_Context)
{
	new_layout_group: Layout_Group;
	append(&layout_stack, new_layout_group);
}

apply_anchor_padding :: proc(rect: util.Rect, anchor: Anchor, padding: Padding) -> (result: util.Rect)
{
	result.pos = rect.pos + rect.size * anchor.min + padding.top_left;
	result.size = rect.size * (anchor.max - anchor.min) - padding.top_left - padding.bottom_right;
	return result;
}

pop_layout_group :: proc(using ui_ctx: ^UI_Context)
{
	popped_layout_group := pop(&layout_stack);
	parent_used_rect := &current_layout(ui_ctx).used_rect;
	for layout in popped_layout_group.layouts
	{
		display_rect := util.Rect{
			pos = layout.used_rect.pos - layout.padding.top_left,
			size = layout.used_rect.size + layout.padding.top_left + layout.padding.bottom_right,
		};
		for draw_command in layout.draw_commands
		{
			draw_command.final_cmd.pos = display_rect.pos;
			draw_command.final_cmd.size = display_rect.size;
		}
		parent_used_rect^ = join_rects(parent_used_rect^, display_rect);
	}
}

render_layout_commands :: proc(using ui_ctx: ^UI_Context)
{
	current_layout_group := layout_stack[len(layout_stack)-1];
	for layout in current_layout_group.layouts
	{
		for draw_command in layout.draw_commands
		{
			draw_command.final_cmd.pos = layout.used_rect.pos - layout.padding.top_left;
			draw_command.final_cmd.size = layout.used_rect.size + layout.padding.top_left + layout.padding.bottom_right;
		}
	}
}

add_layout_to_group :: proc(using ui_ctx: ^UI_Context, layout: Layout)
{
	current_layout_group := &layout_stack[len(layout_stack)-1];
	append(&current_layout_group.layouts, layout);
}

next_layout :: proc(using ui_ctx: ^UI_Context)
{
	current_group := &layout_stack[len(layout_stack)-1];
	current_group.cursor = (current_group.cursor + 1) % len(current_group.layouts);
}

current_layout :: proc(using ui_ctx: ^UI_Context) -> ^Layout
{
	current_group := layout_stack[len(layout_stack)-1];
	return &current_group.layouts[current_group.cursor];
}

rect :: proc(draw_list: ^Draw_List, rect: util.Rect, color: Color, corner_radius: f32 = 0)
{
	uv_rect := util.Rect { size = [2]f32{1, 1}};
	append(draw_list, Rect_Draw_Command{rect = rect, uv_rect= uv_rect, color = color, corner_radius = corner_radius});
}

rect_border :: proc(draw_list: ^Draw_List, rect: util.Rect, color: Color, thickness: f32 = 1)
{
	uv_rect:= util.Rect { size = [2]f32{1, 1}};
	append(draw_list, Rect_Draw_Command{
		rect = util.Rect{rect.pos, [2]f32{rect.size.x, thickness}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});

	append(draw_list, Rect_Draw_Command{
		rect = util.Rect{rect.pos, [2]f32{thickness, rect.size.y}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});
	append(draw_list, Rect_Draw_Command{
		rect = util.Rect{rect.pos + [2]f32{rect.size.x - thickness, 0}, [2]f32{thickness, rect.size.y}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});
	append(draw_list, Rect_Draw_Command{
		rect = util.Rect{rect.pos + [2]f32{0, rect.size.y - thickness}, [2]f32{rect.size.x, thickness}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});
}

textured_rect :: proc(
	rect: util.Rect,
	color: Color,
	sprite: render.Sprite_Handle,
	draw_list: ^Draw_List, 
)
{
	sprite_data: ^render.Sprite = container.handle_get(sprite);
	texture_handle := sprite_data.texture;
	append(draw_list, Rect_Draw_Command{
		rect = rect,
		uv_rect = sprite_data.clip,
		color = color,
		texture = texture_handle,
	});
}

ui_element :: proc(
	ctx: ^UI_Context,
	rect: util.Rect,
	interactions: Interactions,
	location := #caller_location,
	additional_element_index: i32 = 0,
) -> (out_state: Element_State)
{
	to_hash := make([]byte, len(transmute([]byte)location.file_path) + size_of(i32) * 2);
	mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path));
	location_line := location.line;
	additional_element_index := additional_element_index;
	mem.copy(&to_hash[len(location.file_path)], &location_line, size_of(i32));
	mem.copy(&to_hash[len(location.file_path) + size_of(i32)], &additional_element_index, size_of(i32));
	element_id:= UI_ID(hash.djb2(to_hash));
	ctx.current_element = UI_Element{rect, element_id};
	mouse_over :=  ctx.input_state.cursor_pos.x > rect.pos.x 			\
			&& ctx.input_state.cursor_pos.y > rect.pos.y 				\
			&& ctx.input_state.cursor_pos.x < rect.pos.x + rect.size.x	\
			&& ctx.input_state.cursor_pos.y < rect.pos.y + rect.size.y;
	
	available_interactions: Interactions;
	switch ctx.input_state.cursor_state
	{
		case .Normal:
			available_interactions = {.Hover};
		case .Press:
			available_interactions = {.Press};
		case .Down:
			available_interactions = {.Press};
		case .Drag:
			available_interactions = {.Hover};
			if element_id == ctx.input_state.drag_target do incl(&out_state, Interaction_Type.Drag);
		case .Click_Release:
			available_interactions = {.Click, .Hover};
		case .Drag_Release:
			available_interactions = {.Hover};
	}

	for interaction_type in Interaction_Type 
	{
		if interaction_type in interactions
		{
			under_cursor, has_under_cursor := ctx.elements_under_cursor[interaction_type];
			if has_under_cursor && under_cursor == element_id
			{
				if interaction_type in available_interactions
				{
					incl(&out_state, interaction_type);
				}
				if !mouse_over do ctx.next_elements_under_cursor[interaction_type] = 0;
			}
			if mouse_over
			{
				ctx.next_elements_under_cursor[interaction_type] = element_id;
			}
		}
	}
	layout := current_layout(ctx);
	use_rect_in_layout(ctx, rect);
	return;
}

use_rect_in_layout :: proc(ctx: ^UI_Context, rect: util.Rect)
{
	layout := current_layout(ctx);
	if layout.used_rect.size.x == 0 || layout.used_rect.size.y == 0
	{
		layout.used_rect = rect;
	}
	else
	{
		layout.used_rect = join_rects(layout.used_rect, rect);
	}
}

element_draw_themed_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding, theme: ^Rect_Theme)
{
	padding_sum := [2]f32{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := UI_Rect{
		pos = linalg.to_i32(ctx.current_element.pos + anchor.min * ctx.current_element.size + [2]f32{anchor.left, anchor.top}),
		size = linalg.to_i32(ctx.current_element.size * (anchor.max - anchor.min) - padding_sum),
	};
	log.info(theme^);
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = rect,
		theme = theme^,
	});
}

element_draw_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding, color: Color, corner_radius: f32 = 0)
{
	padding_sum := [2]f32{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := UI_Rect{
		pos = linalg.to_i32(ctx.current_element.pos + anchor.min * ctx.current_element.size + [2]f32{anchor.left, anchor.top}),
		size = linalg.to_i32(ctx.current_element.size * (anchor.max - anchor.min) - padding_sum),
	};
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = rect,
		theme = {
			fill_color = color,
			corner_radius = 10,
			border_color = 0x000000ff,
			border_thickness = 1,
		},
	});
	//append(&ctx.draw_list, Rect_Draw_Command{rect = rect, clip = clip, color = color, corner_radius = corner_radius});
}

element_draw_textured_rect :: proc(
	anchor: Anchor,
	padding: Padding,
	color: Color,
	sprite: render.Sprite_Handle,
	ctx: ^UI_Context,
)
{
	padding_sum := [2]f32{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := util.Rect{
		pos = ctx.current_element.pos + anchor.min * ctx.current_element.size + [2]f32{anchor.left, anchor.top},
		size = ctx.current_element.size * (anchor.max - anchor.min) - padding_sum,
	};
	sprite_data: ^render.Sprite = container.handle_get(sprite);
	texture_handle := sprite_data.texture;
	append(&ctx.draw_list, Rect_Draw_Command{
		rect = rect,
		uv_rect = sprite_data.clip,
		color = color,
		texture = texture_handle,
	});
}

text :: proc(
	text: string,
	color: Color,
	pos: [2]f32,
	font: ^render.Font,
	ctx: ^UI_Context,
) {
	pos_cursor := linalg.to_int(pos);
	render.load_glyphs(&ctx.font_atlas, ctx.sprite_table, font, text);
	for char in text
	{
		glyph, glyph_found := font.glyphs[char]; 
		assert(glyph_found);
		rect := UI_Rect{ pos = linalg.to_i32(pos_cursor + glyph.bearing), size = linalg.to_i32(glyph.size) };
		//textured_rect(rect, color, glyph.sprite, &ctx.draw_list);

		glyph_sprite := container.handle_get(glyph.sprite);
		texture := container.handle_get(glyph_sprite.texture);

		add_rect_command(&ctx.ui_draw_list, Rect_Command{
			rect = rect,
			uv_clip = glyph_sprite.clip,
			theme = {
				fill_color = color,
			},
			texture_id = texture.bindless_id,
		});
		pos_cursor += glyph.advance / 64;
	}
}

multiline_text :: proc(
	str: string,
	color: Color,
	pos: [2]f32,
	line_size: int,
	font: ^render.Font,
	ctx: ^UI_Context,
) {
	for substring, index in render.split_text_for_render(font, str, line_size)
	{
		text(substring, color, pos + [2]f32{0, f32(font.line_height) * f32(index)}, font, ctx);
	}
}

element_draw_text :: proc(
	padding: Padding,
	text: string,
	color: Color,
	font: ^render.Font,
	ctx: ^UI_Context,
) {
	pos_cursor := ctx.current_element.pos + padding.top_left + [2]f32{0, font.line_height};
	line_size := int(ctx.current_element.pos.x + ctx.current_element.size.x - pos_cursor.x - padding.bottom_right.x);
	multiline_text(text, color, pos_cursor, line_size, font, ctx);
}

add_and_get_draw_command :: proc(array: ^Draw_List, draw_cmd: $T) -> ^T
{
	added_cmd := util.append_and_get(array);
	added_cmd^ = draw_cmd;
	return cast(^T)added_cmd;
}

layout_draw_used_rect :: proc(anchor: Anchor, padding: Padding, color: Color, ctx: ^UI_Context)
{
	draw_cmd := add_and_get_draw_command(&ctx.draw_list, Rect_Draw_Command{color=color});
	layout_cmd := Layout_Draw_Command{draw_cmd, anchor, padding};
	append(&current_layout(ctx).draw_commands, layout_cmd);
}

// TODO : utility functions to get an anchored / padded sub rect ?
layout_get_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding) -> util.Rect
{
	layout := current_layout(ctx);
	return {pos = layout.pos, size = layout.size};
}

layout_draw_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding, color: Color, corner_radius: f32)
{
	layout := current_layout(ctx);
	draw_cmd := Rect_Draw_Command{
		rect = {
			pos = layout.pos,
			size = layout.size,
		},
		color = color,
		corner_radius = corner_radius,
	};
	append(&ctx.draw_list, draw_cmd);

	layout_rect := layout_get_rect(ctx, anchor, padding);
	add_rect_command(&ctx.ui_draw_list, Rect_Command {
		rect = UI_Rect{pos = linalg.to_i32(layout.pos), size = linalg.to_i32(layout.size)},
		uv_clip = {{0, 0}, {1, 1}},
		theme = {
			fill_color = color,
			border_color = render.rgb(0, 0, 0),
			border_thickness = 1,
		},
	});
}

default_anchor :: Anchor{{0, 0}, {1, 1}, 0, 0, 0, 0};

drag_box :: proc(
	rect: util.Rect,
	drag_state: ^Drag_State,

	ui_ctx: ^UI_Context,
	location := #caller_location,
) -> (state_changed: bool)
{
	element_state := ui_element(ui_ctx, rect, {.Drag}, location);
	if Interaction_Type.Drag in element_state
	{
		drag_state.drag_offset += ui_ctx.input_state.delta_drag;
		drag_state.drag_last_pos = ui_ctx.input_state.cursor_pos;
		return true;
	}
	return false;
}

allocate_element_space :: proc(ui_ctx: ^UI_Context, size: [2]f32) -> util.Rect
{
	layout := current_layout(ui_ctx);
	result := util.Rect{layout.pos + layout.padding.top_left + layout.cursor * layout.direction, size};
	if layout.direction.x < 0
	{
		result.pos.x = layout.pos.x + layout.size.x - layout.padding.bottom_right.x - layout.cursor - size.x;
	}
	if layout.direction.y < 0
	{
		result.pos.y = layout.pos.y + layout.size.y - layout.padding.bottom_right.y - layout.cursor - size.y;
	}
	if size.x == 0
	{
		result.size.x = layout.size.x;
	}
	if size.y == 0
	{
		result.size.y = layout.size.y;
	}
	layout.cursor += linalg.vector_dot(result.size, linalg.to_f32(layout.direction));
	use_rect_in_layout(ui_ctx, result);
	return result;
}

button :: proc(
	label: string,
	size: [2]f32,

	using ui_ctx: ^UI_Context,
	location := #caller_location,
) -> (clicked: bool)
{
	layout := current_layout(ui_ctx);
	allocated_space := allocate_element_space(ui_ctx, size);
	element_state := ui_element(ui_ctx, allocated_space, {.Hover, .Press, .Click}, location);
	color: Color;

	used_theme: Rect_Theme;
	using current_theme.button;
	if Interaction_Type.Press in element_state
	{
		used_theme = clicked_theme;
	}
	else if Interaction_Type.Hover in element_state 
	{
		used_theme = hovered_theme;
	}
	else
	{
		used_theme = default_theme;
	}
	if(corner_radius_unit == Unit.Ratio) do used_theme.corner_radius *= allocated_space.size.y / 2;
	element_draw_themed_rect(ui_ctx, {{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, &used_theme);
	
	return Interaction_Type.Click in element_state;
}

vsplit :: proc{
	vsplit_layout_ratio,
	vsplit_layout_sizes,
};

vsplit_layout_ratio :: proc(using ui_ctx: ^UI_Context, layout: Layout, split_ratio: f32, inner_padding: Padding) -> [2]Layout
{
	parent_layout := current_layout(ui_ctx)^;
	left_split_width := parent_layout.size.x * split_ratio;
	out_layouts: [2]Layout = {
		{
			rect = util.Rect {
				pos = parent_layout.pos,
				size = [2]f32{left_split_width, parent_layout.size.y},
			},
			padding = inner_padding,
			direction = [2]f32{0, 1},
		},
		{
			rect = util.Rect {
				pos = [2]f32 {parent_layout.pos. x + left_split_width, parent_layout.pos.y},
				size = [2]f32{parent_layout.size.x - left_split_width, parent_layout.size.y},
			},
			padding = inner_padding,
			direction = [2]f32{0, 1},
		},
	};
	return out_layouts;
}

vsplit_layout_weights :: proc(using ui_ctx: ^UI_Context, split_weights: []f32, inner_padding: Padding, allocator := context.temp_allocator) -> []Layout
{
	parent_layout := current_layout(ui_ctx)^;
	left_split_width := parent_layout.size.x * split_ratio;

	result := make([]Layout, len(split_sizes));

	weights_sum := 0;
	for(i in 0..<len(split_weights))
	{
		weights_sum += split_weights[i];
	}

	for(i in 0..<len(split_sizes))
	{
		width := parent_layout.size.x * split_weights[i] / weights_sum;
		result[i] = Layout {
			rect = util.Rect {
				pos = parent_layout.pos,
				size = [2]f32{width, parent_layout.size.y},
			},
			padding = inner_padding,
			direction = [2]f32{0, 1},
		};
	}
	out_layouts[1] = out_layouts[0];
	out_layouts[0].size.x = left_split_width;
	out_layouts[1].pos.x += left_split_width;
	out_layouts[1].size.x = parent_layout.size.x * (1 - split_ratio);
}

round_corner_subdivisions :: 3;

render_draw_list :: proc(draw_list: ^Draw_List, render_system: ^render.Sprite_Render_System)
{

	push_rect_data :: proc(render_system: ^render.Sprite_Render_System, using rect: util.Rect, clip: util.Rect, color: render.Color)
	{
		vertices: [dynamic]render.Sprite_Vertex_Data;
		indices: [dynamic]u32;
		quad_index_list := [?]u32{0, 1, 2, 0, 2, 3};
		start_index := u32(len(vertices));
		vertice: render.Sprite_Vertex_Data = {pos, clip.pos, color};
		append(&vertices, vertice);
		vertice.pos.x = pos.x + size.x;
		vertice.uv.x = clip.pos.x + clip.size.x;
		append(&vertices, vertice);
		vertice.pos.y = pos.y + size.y;
		vertice.uv.y = clip.pos.y + clip.size.y;
		append(&vertices, vertice);
		vertice.pos.x = pos.x;
		vertice.uv.x = clip.pos.x;
		append(&vertices, vertice);
		for index_offset in quad_index_list
		{
			append(&indices, start_index + index_offset);
		}
		render.push_mesh_data(&render_system.buffer, vertices[:], indices[:]);
		clear(&vertices);
		clear(&indices);
	}

	push_corner_data :: proc(render_system: ^render.Sprite_Render_System, pos: [2]f32, dir: [2]f32, color: Color)
	{
		vertices: [dynamic]render.Sprite_Vertex_Data;
		indices: [dynamic]u32;
		vertice: render.Sprite_Vertex_Data = {pos, {}, color};
		append(&vertices, vertice);
		for i in 0..round_corner_subdivisions
		{
			angle := f32(i) / f32(round_corner_subdivisions) * math.PI / 2;
			vertice.pos = pos + [2]f32{dir.x * math.cos(angle), dir.y * math.sin(angle)};
			append(&vertices, vertice);
		}
		for i in 0..<round_corner_subdivisions
		{
			append(&indices, 0);
			append(&indices, u32(i) + 1);
			append(&indices, u32(i) + 2);
		}
		render.push_mesh_data(&render_system.buffer, vertices[:], indices[:]);
		clear(&vertices);
		clear(&indices);
	}

	for draw_cmd in draw_list
	{
		switch cmd_data in draw_cmd
		{
			case Clip_Draw_Command:
				
			case Rect_Draw_Command:
				render.use_texture(render_system, cmd_data.texture);
				if cmd_data.corner_radius > 0
				{
					using cmd_data;
					push_rect_data(
						render_system, 
						{
							pos + [2]f32{0, corner_radius},
							[2]f32{corner_radius, size.y - 2 * corner_radius},
						}, 
						cmd_data.uv_rect, 
						cmd_data.color,
					);
					push_rect_data(
						render_system, 
						{
							pos + [2]f32{corner_radius, 0},
							[2]f32{size.x - corner_radius * 2, size.y},
						}, 
						uv_rect, 
						cmd_data.color,
					);
					push_rect_data(
						render_system, 
						{
							pos + [2]f32{size.x - corner_radius, corner_radius}, 
							[2]f32{corner_radius, size.y - 2 * corner_radius},
						}, 
						cmd_data.uv_rect, 
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + [2]f32{corner_radius, corner_radius},
						[2]f32{-corner_radius, -corner_radius},
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + [2]f32{cmd_data.size.x - corner_radius, corner_radius},
						[2]f32{corner_radius, -corner_radius},
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + [2]f32{corner_radius, cmd_data.size.y - corner_radius},
						[2]f32{-corner_radius, corner_radius},
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + cmd_data.size - [2]f32{corner_radius, corner_radius},
						[2]f32{corner_radius, corner_radius},
						cmd_data.color,
					);
				}
				else
				{
					push_rect_data(render_system, {cmd_data.pos, cmd_data.size}, cmd_data.uv_rect, cmd_data.color);
				}
		}
	}
	clear(draw_list);
}
