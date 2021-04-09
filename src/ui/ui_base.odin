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
	ui_ctx.editor_config.line_height = 50;

}

update_input_state :: proc(ui_ctx: ^UI_Context, input_state: ^input.State)
{
	using ui_ctx.input_state;
	last_cursor_pos = cursor_pos;
	cursor_pos = linalg.to_f32(input_state.mouse_pos);
	cursor_offset := cursor_pos - last_cursor_pos; 
	log.info(cursor_state);
	switch cursor_state 
	{
		case .Normal:
			if input.Key_State_Flags.Down in input.get_mouse_state(input_state, 0)
			{
				cursor_state = Cursor_Input_State.Press;
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
	base_layout := Layout{
		pos = {0, 0}, size = screen_size,
		direction = [2]f32{0, 1},
	};
	push_layout_group(ui_ctx);
	add_layout_to_group(ui_ctx, base_layout);
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

rect :: proc(draw_list: ^Draw_List, pos: [2]f32, size: [2]f32, color: Color)
{
	clip_rect := util.Rect { size = [2]f32{1, 1}};
	append(draw_list, Rect_Draw_Command{rect = util.Rect{pos, size}, clip = clip_rect, color = color});
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
		clip = sprite_data.clip,
		color = color,
		texture = texture_handle
	});
}

ui_element :: proc(
	ctx: ^UI_Context,
	rect: util.Rect,
	interactions: Interactions,
	location := #caller_location,
	additional_element_index: i32 = 0
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
	layout.used_rect = join_rects(layout.used_rect, util.Rect{ctx.current_element.pos, ctx.current_element.size});
	return;
}

element_draw_rect :: proc(anchor: Anchor, padding: Padding, color: Color, ctx: ^UI_Context)
{
	padding_sum := [2]f32{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := util.Rect{
		pos = ctx.current_element.pos + anchor.min * ctx.current_element.size + [2]f32{anchor.left, anchor.top},
		size = ctx.current_element.size * (anchor.max - anchor.min) - padding_sum,
	};
	clip := util.Rect{ size = [2]f32{1, 1} };
	append(&ctx.draw_list, Rect_Draw_Command{rect = rect, clip = clip, color = color});
}

element_draw_textured_rect :: proc(
	anchor: Anchor,
	padding: Padding,
	color: Color,
	sprite: render.Sprite_Handle,
	ctx: ^UI_Context
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
		clip = sprite_data.clip,
		color = color,
		texture = texture_handle
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
		rect := util.Rect{ pos = linalg.to_f32(pos_cursor + glyph.bearing), size = linalg.to_f32(glyph.size) };
		textured_rect(rect, color, glyph.sprite, &ctx.draw_list);
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
	ctx: ^UI_Context
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

layout_draw_rect :: proc(anchor: Anchor, padding: Padding, color: Color, ctx: ^UI_Context)
{
	layout := current_layout(ctx);
	draw_cmd := Rect_Draw_Command{
		rect = {
			pos = layout.pos,
			size = layout.size,
		},
		color = color,
	};
	append(&ctx.draw_list, draw_cmd);
}

default_anchor :: Anchor{{0, 0}, {1, 1}, 0, 0, 0, 0};

button :: proc(
	txt: 	string,
	rect: util.Rect,

	ui_ctx: ^UI_Context,
	location := #caller_location
) -> bool
{
	state := ui_element(ui_ctx, rect, {.Hover, .Press, .Click}, location);
	if Interaction_Type.Press in state
	{
		element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{0, 1, 1, 1}, ui_ctx);
		element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{0.5, 0.5, 0.5, 1}, ui_ctx);
	}
	else if Interaction_Type.Hover in state
	{
		element_draw_rect(default_anchor, {}, render.Color{1, 0, 0, 1}, ui_ctx);
		element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	else
	{
		element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{0, 1, 0, 1}, ui_ctx);
		element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	return Interaction_Type.Click in state;
}

drag_box :: proc(
	rect: util.Rect,
	drag_state: ^Drag_State,

	ui_ctx: ^UI_Context,
	location := #caller_location
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
	return result;
}

layout_button :: proc(
	label: string,
	size: [2]f32,

	using ui_ctx: ^UI_Context,
	location := #caller_location
) -> (clicked: bool)
{
	layout := current_layout(ui_ctx);
	allocated_space := allocate_element_space(ui_ctx, size);
	element_state := ui_element(ui_ctx, allocated_space, {.Hover, .Click}, location);

	if Interaction_Type.Press in element_state
	{
		element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{1, 0, 0, 1}, ui_ctx);
		element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	else if Interaction_Type.Hover in element_state 
	{
		element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{1, 0, 0, 1}, ui_ctx);
		element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	else
	{
		element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{0, 1, 0, 1}, ui_ctx);
		element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	
	return Interaction_Type.Click in element_state;
}

vsplit_layout :: proc(split_ratio: f32, inner_padding: Padding, using ui_ctx: ^UI_Context)
{
	parent_layout := current_layout(ui_ctx)^;
	left_split_width := parent_layout.size.x * split_ratio;
	new_layout := Layout {
		pos = parent_layout.pos,
		size = [2]f32{left_split_width, parent_layout.size.y},
		padding = inner_padding,
		direction = [2]f32{0, 1},
	};
	new_layout.size.x = left_split_width;
	push_layout_group(ui_ctx);
	add_layout_to_group(ui_ctx, new_layout);
	new_layout.pos.x += left_split_width;
	new_layout.size.x = parent_layout.size.x * (1 - split_ratio);
	add_layout_to_group(ui_ctx, new_layout);
}

window :: proc(using state: ^Window_State, header_height: f32, using ui_ctx: ^UI_Context) -> (draw_content: bool)
{ 
	push_layout_group(ui_ctx);
	header_size := [2]f32{rect.size.x, header_height};
	header_layout := Layout {
		pos = rect.pos,
		size = header_size,
		direction = [2]f32{-1, 0},
	};

	// Close button layout
	add_layout_to_group(ui_ctx, header_layout);

	// Main Header Layout
	header_layout.direction.x = 1;
	add_layout_to_group(ui_ctx, header_layout);

	draw_content = !state.folded;

	if draw_content
	{
		// Body Layout
		body_layout := Layout {
			pos = rect.pos + [2]f32{0, header_height},
			size = [2]f32{rect.size.x, rect.size.y - header_height},
			direction = [2]f32{0, 1},
		};
		
		add_layout_to_group(ui_ctx, body_layout);
	}

	layout_draw_rect({}, {}, Color{0.5, 0.5, 0.5, 0.3}, ui_ctx);
	// Close button
	if drag_box(util.Rect{rect.pos, header_size}, &drag_state, ui_ctx)
	{
		rect.pos += drag_state.drag_offset;
		drag_state.drag_offset = [2]f32{0, 0};
	}
	layout_button("close button", {header_height, header_height}, ui_ctx); 
	next_layout(ui_ctx);
	if layout_button("fold button", {header_height, header_height}, ui_ctx)
	{
		state.folded = !state.folded;
	}
	next_layout(ui_ctx);
	if draw_content do layout_draw_rect({}, {}, Color{1, 0, 0, 0.8}, ui_ctx);
	return;
}

render_draw_list :: proc(draw_list: ^Draw_List, render_system: ^render.Sprite_Render_System)
{
	vertices: [dynamic]render.Sprite_Vertex_Data;
	indices: [dynamic]u32;
	quad_index_list := [?]u32{0, 1, 2, 0, 2, 3};
	for draw_cmd in draw_list
	{
		switch cmd_data in draw_cmd
		{
			case Rect_Draw_Command:
				start_index := u32(len(vertices));
				vertice: render.Sprite_Vertex_Data = {cmd_data.pos, cmd_data.clip.pos, cmd_data.color};
				append(&vertices, vertice);
				vertice.pos.x = cmd_data.pos.x + cmd_data.size.x;
				vertice.uv.x = cmd_data.clip.pos.x + cmd_data.clip.size.x;
				append(&vertices, vertice);
				vertice.pos.y = cmd_data.pos.y + cmd_data.size.y;
				vertice.uv.y = cmd_data.clip.pos.y + cmd_data.clip.size.y;
				append(&vertices, vertice);
				vertice.pos.x = cmd_data.pos.x;
				vertice.uv.x = cmd_data.clip.pos.x;
				append(&vertices, vertice);
				for index_offset in quad_index_list
				{
					append(&indices, start_index + index_offset);
				}
				render.use_texture(render_system, cmd_data.texture);
				render.push_mesh_data(&render_system.buffer, vertices[:], indices[:]);
				clear(&vertices);
				clear(&indices);
				
		}
	}
	clear(draw_list);
}
