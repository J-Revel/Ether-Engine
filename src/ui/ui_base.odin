package ui

import "../render"
import "core:log"
import "core:hash"
import "core:math/linalg"
import "core:runtime"
import "../input"

reset_ctx :: proc(using ui_ctx: ^UI_Context, input_state: ^input.State, screen_size: [2]f32)
{
	mouse_pos = {f32(input_state.mouse_pos.x), f32(input_state.mouse_pos.y)};
	hovered_element = ui_ctx.next_hovered_element;
	next_hovered_element = 0;
	mouse_click = input.get_mouse_state(input_state, 0) == input.Key_State.Pressed;
	clear(&layout_stack);
	base_layout := Layout{
		pos = {0, 0}, size = screen_size,
		direction = [2]int{0, 1},
		cursor = {0, 0},
	};
	push_layout_group(ui_ctx);
	add_layout_to_group(ui_ctx, base_layout);
}

push_layout_group :: proc(using ui_ctx: ^UI_Context)
{
	new_layout_group: Layout_Group;
	append(&layout_stack, new_layout_group);
}

pop_layout_group :: proc(using ui_ctx: ^UI_Context)
{
	popped_layout_group := pop(&layout_stack);
	for layout in popped_layout_group.layouts
	{
		for draw_command in layout.draw_commands
		{
			draw_command.final_cmd.pos = layout.pos;
			draw_command.final_cmd.size = layout.size;
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
	append(draw_list, Rect_Draw_Command{pos, size, color});
}

/*
	usage code
	if gui.clickable_element(pos, size)
	{
		gui.element_draw_rect(anchor, padding, color);
	}
*/

ui_element :: proc(
	pos: [2]f32,
	size: [2]f32,
	ctx: ^UI_Context,
	location := #caller_location
) -> (state: Element_State)
{
	state = .Normal;
	element_hash := uintptr(hash.djb2(transmute([]byte)location.file_path)) + uintptr(location.line);
	ctx.current_element = element_hash;
	ctx.current_element_pos = pos;
	ctx.current_element_size = size;
	mouse_over :=  ctx.mouse_pos.x > pos.x 
			&& ctx.mouse_pos.y > pos.y
			&& ctx.mouse_pos.x < pos.x + size.x
			&& ctx.mouse_pos.y < pos.y + size.y;

	if ctx.hovered_element == element_hash
	{
		state = .Hovered;
		if !mouse_over do ctx.hovered_element = 0;
	}
	if mouse_over
	{
		ctx.next_hovered_element = element_hash;
	}
	return;
}

element_draw_rect :: proc(anchor: UI_Anchor, color: Color, ctx: ^UI_Context)
{
	pos := ctx.current_element_pos + anchor.min * ctx.current_element_size + [2]f32{anchor.left, anchor.top};
	size := ctx.current_element_size * (anchor.max - anchor.min) - [2]f32{anchor.right + anchor.left, anchor.bottom + anchor.top};
	append(&ctx.draw_list, Rect_Draw_Command{pos, size, color});
}

layout_draw_rect :: proc(anchor: UI_Anchor, color: Color, ctx: ^UI_Context)
{
	append(&ctx.draw_list, Rect_Draw_Command{{}, {}, color});
	draw_cmd := &ctx.draw_list[len(ctx.draw_list)-1];
	layout_draw_cmd := Layout_Draw_Command{draw_cmd, anchor};
	append(&current_layout().draw_commands, layout_draw_cmd);
}

button :: proc(
	label: 	string,
	pos: 	[2]f32,
	size: 	[2]f32,

	ui_ctx: ^UI_Context,
	location := #caller_location
) -> bool
{
	#partial switch ui_element(pos, size, ui_ctx, location)
	{
		case .Hovered:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, render.Color{1, 0, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, render.Color{1, 1, 0, 1}, ui_ctx);
			return ui_ctx.mouse_click;

		case .Normal:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, render.Color{0, 1, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	return false;
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
	#partial switch ui_element(layout.pos, size, ui_ctx, location)
	{
		case .Hovered:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, render.Color{1, 0, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, render.Color{1, 1, 0, 1}, ui_ctx);
			clicked = ui_ctx.mouse_click;

		case .Normal:
			element_draw_rect({{0, 0}, {1, 1}, 0, 0, 0, 0}, render.Color{0, 1, 0, 1}, ui_ctx);
			element_draw_rect({{0, 0}, {1, 1}, 5, 5, 5, 5}, render.Color{1, 1, 0, 1}, ui_ctx);
	}
	layout.pos += size * linalg.to_f32(layout.direction);
	return;
}

vsplit_layout :: proc(split_ratio: f32, using ui_ctx: ^UI_Context)
{
	new_layout := current_layout(ui_ctx)^;
	total_width := new_layout.size.x;
	left_split_width := total_width * split_ratio;
	new_layout.size.x -= left_split_width;
	push_layout_group(ui_ctx);
	add_layout_to_group(ui_ctx, new_layout);
	new_layout.pos.x += left_split_width;
	new_layout.size.x = total_width * (1 - split_ratio);
	add_layout_to_group(ui_ctx, new_layout);
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
