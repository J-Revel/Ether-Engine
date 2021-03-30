package ui

import "../render"
import "core:log"
import "core:hash"
import "core:math/linalg"
import "core:math"
import "core:runtime"
import "../input"

join_rects :: proc(A: Rect, B: Rect) -> (result: Rect)
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

reset_ctx :: proc(ui_ctx: ^UI_Context, input_state: ^input.State, screen_size: [2]f32)
{
	ui_ctx.input_state.cursor_pos = linalg.to_f32(input_state.mouse_pos);
	ui_ctx.hovered_element = ui_ctx.next_hovered_element;
	ui_ctx.next_hovered_element = 0;
	for i in 0..<3
	{
		ui_ctx.input_state.mouse_states[i] = input.get_mouse_state(input_state, i);
	}
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

apply_anchor_padding :: proc(rect: Rect, anchor: Anchor, padding: Padding) -> (result: Rect)
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
		display_rect := Rect{
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
	append(draw_list, Rect_Draw_Command{Rect{pos, size}, color});
}

ui_element :: proc(using rect: Rect, ctx: ^UI_Context, location := #caller_location) -> (state: Element_State)
{
	state = .Normal;
	element_hash := uintptr(hash.djb2(transmute([]byte)location.file_path)) + uintptr(location.line);
	ctx.current_element = element_hash;
	ctx.current_element_pos = pos;
	ctx.current_element_size = size;
	mouse_over :=  ctx.input_state.cursor_pos.x > pos.x 		\
			&& ctx.input_state.cursor_pos.y > pos.y 			\
			&& ctx.input_state.cursor_pos.x < pos.x + size.x	\
			&& ctx.input_state.cursor_pos.y < pos.y + size.y;

	if ctx.hovered_element == element_hash
	{
		state = .Hovered;
		if !mouse_over do ctx.hovered_element = 0;
	}
	if mouse_over
	{
		ctx.next_hovered_element = element_hash;
	}
	layout := current_layout(ctx);
	layout.used_rect = join_rects(layout.used_rect, Rect{ctx.current_element_pos, ctx.current_element_size});
	return;
}

element_draw_rect :: proc(anchor: Anchor, padding: Padding, color: Color, ctx: ^UI_Context)
{
	padding_sum := [2]f32{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := Rect{
		pos = ctx.current_element_pos + anchor.min * ctx.current_element_size + [2]f32{anchor.left, anchor.top},
		size = ctx.current_element_size * (anchor.max - anchor.min) - padding_sum,
	};;
	append(&ctx.draw_list, Rect_Draw_Command{rect, color});
}

append_and_get :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> ^E #no_bounds_check
{
    if array == nil do return nil;

    n := len(array);
    resize(array, n+1);

    return len(array) == n+1 ? &array[len(array)-1] : nil;
}

add_and_get_draw_command :: proc(array: ^Draw_List, draw_cmd: $T) -> ^T
{
	added_cmd := append_and_get(array);
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

button :: proc(
	label: 	string,
	rect: Rect,

	ui_ctx: ^UI_Context,
	location := #caller_location
) -> bool
{
	#partial switch ui_element(rect, ui_ctx, location)
	{
		case .Hovered:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{1, 0, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
			return ui_ctx.input_state.mouse_states[0] == input.Key_State_Pressed;

		case .Normal:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{0, 1, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	return false;
}

/* 
	Drag box usage code :
	drag_state: Drag_State;
	if drag_box(rect, &drag_state, ui_ctx)
	{
		// state changed
	}
*/
drag_box :: proc(
	rect: Rect,
	drag_state: ^Drag_State,

	ui_ctx: ^UI_Context,
	location := #caller_location
) -> (state_changed: bool)
{
	element_state := ui_element(rect, ui_ctx, location);
	if drag_state.dragging
	{
		if ui_ctx.input_state.mouse_states[0] < input.Key_State_Down
		{
			drag_state.dragging = false;
			state_changed = true;
		}
		mouse_offset := ui_ctx.input_state.cursor_pos - drag_state.drag_last_pos;
		if mouse_offset.x != 0 || mouse_offset.y != 0
		{
			drag_state.drag_offset += mouse_offset;
			drag_state.drag_last_pos = ui_ctx.input_state.cursor_pos;
			state_changed = true;
		}
	}
	else
	{
		if ui_ctx.input_state.mouse_states[0] == input.Key_State_Pressed && element_state == .Hovered
		{
			drag_state.dragging = true;
			drag_state.drag_last_pos = ui_ctx.input_state.cursor_pos;
			state_changed = true;
		}
	}
	return;
}

allocate_element_space :: proc(ui_ctx: ^UI_Context, size: [2]f32) -> Rect
{
	layout := current_layout(ui_ctx);
	result := Rect{layout.pos + layout.padding.top_left + layout.cursor * layout.direction, size};
	if layout.direction.x < 0
	{
		result.pos.x = layout.pos.x + layout.size.x - layout.padding.bottom_right.x - layout.cursor - size.x;
	}
	if layout.direction.y < 0
	{
		result.pos.y = layout.pos.y + layout.size.y - layout.padding.bottom_right.y - layout.cursor - size.y;
	}
	layout.cursor += linalg.vector_dot(size, linalg.to_f32(layout.direction));
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
	clicked = false;
	allocated_space := allocate_element_space(ui_ctx, size);
	element_state := ui_element(allocated_space, ui_ctx, location);

	#partial switch element_state 
	{
		case .Hovered:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{1, 0, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
			clicked = ui_ctx.input_state.mouse_states[0] == input.Key_State_Pressed;

		case .Normal:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, render.Color{0, 1, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, {}, render.Color{1, 1, 0, 1}, ui_ctx);
	}

	return;
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
	if drag_box(Rect{rect.pos, header_size}, &drag_state, ui_ctx)
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

render_draw_list :: proc(draw_list: ^Draw_List, render_buffer: ^render.Color_Render_Buffer)
{
	vertices: [dynamic]render.Color_Vertex_Data;
	indices: [dynamic]u32;
	quad_index_list := [?]u32{0, 1, 2, 0, 2, 3};
	for draw_cmd in draw_list
	{
		switch cmd_data in draw_cmd
		{
			case Rect_Draw_Command:
				start_index := u32(len(vertices));
				vertice: render.Color_Vertex_Data = {cmd_data.pos, cmd_data.color};
				append(&vertices, vertice);
				vertice.pos.x = cmd_data.pos.x + cmd_data.size.x;
				append(&vertices, vertice);
				vertice.pos.y = cmd_data.pos.y + cmd_data.size.y;
				append(&vertices, vertice);
				vertice.pos.x = cmd_data.pos.x;
				append(&vertices, vertice);
				for index_offset in quad_index_list
				{
					append(&indices, start_index + index_offset);
				}
		}
	}
	clear(draw_list);
	render.push_mesh_data(render_buffer, vertices[:], indices[:]);
}
