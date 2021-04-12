package ui

import "core:log"

import "core:fmt"
import "../render"
import "../util"

label :: proc(ctx: ^UI_Context, str: string, color: Color = {1, 1, 1, 1}, location := #caller_location, additional_location_index: i32 = 0) -> (state: Element_State)
{
	layout := current_layout(ctx);
	line_height := ctx.current_font.line_height;
	lines := render.split_text_for_render(ctx.current_font, str, int(layout.size.x));
	allocated_length := layout.size.x;
	if len(lines) == 1
	{
		allocated_length = f32(render.get_text_render_size(ctx.current_font, str));
	}
	allocated_space := allocate_element_space(ctx, [2]f32{allocated_length, f32(len(lines)) * line_height});
	first_line_pos := allocated_space.pos + [2]f32{0, line_height};
	for line, index in lines
	{
		text(line, color, first_line_pos + [2]f32{0, f32(line_height) * f32(index)}, ctx.current_font, ctx);
	}
	return state;
}


drag_int :: proc(ctx: ^UI_Context, value: ^int, location := #caller_location, additional_location_index: i32 = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {0, f32(ctx.editor_config.line_height)});
	state := ui_element(ctx, widget_rect, {.Hover, .Press, .Drag}, location, 0);
	text_color := render.Color{1, 1, 1, 1};
	if Interaction_Type.Drag in state
	{
		value^ += int(ctx.input_state.delta_drag.x);
	}
	if Interaction_Type.Drag in state || Interaction_Type.Press in state
	{
		text_color.r = 0;
		element_draw_rect(ctx, default_anchor, {}, render.Color{0.8, 0.8, 0, 1}, 5);
	}
	else if Interaction_Type.Hover in state 
	{
		text_color.r = 0;
		element_draw_rect(ctx, default_anchor, {}, render.Color{1, 1, 0, 1}, 5);
	}
	new_layout := Layout {
		rect = widget_rect,
		direction = {1, 0}
	};
	push_layout_group(ctx);
	add_layout_to_group(ctx, new_layout);
	label(ctx, "drag editor ", text_color, location, additional_location_index + 1);
	label(ctx, fmt.tprint(value^), text_color, location, additional_location_index + 2);
	pop_layout_group(ctx);
}

slider :: proc(ctx: ^UI_Context, value: ^$T, min: T, max: T, location := #caller_location, additional_location_index: i32 = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {0, f32(ctx.editor_config.line_height)});
	rect(&ctx.draw_list, widget_rect, render.Color{1, 1, 1, 1}, 5);
	value_ratio := f32(value^ - min) / f32(max - min);
	cursor_size : f32 = 20;
	cursor_rect := util.Rect {
		pos = widget_rect.pos + [2]f32{cursor_size / 2 + (widget_rect.size.x - cursor_size) * value_ratio - cursor_size / 2, 0},
		size = [2]f32{cursor_size, widget_rect.size.y},
	};
	cursor_state := ui_element(ctx, cursor_rect, {.Hover, .Drag}, location, 0);
	if Interaction_Type.Drag in cursor_state
	{
		new_ratio := (ctx.input_state.cursor_pos.x - widget_rect.pos.x - cursor_size / 2) / (widget_rect.size.x - cursor_size);
		if new_ratio < 0 do new_ratio = 0;
		if new_ratio > 1 do new_ratio = 1;
		value^ = min + T(f32(max - min) * new_ratio);
	}
	rect(&ctx.draw_list, cursor_rect, Color{0.5, 0.5, 0.5, 1}, 5);
}

window :: proc(using state: ^Window_State, header_height: f32, using ui_ctx: ^UI_Context) -> (draw_content: bool)
{ 
	push_layout_group(ui_ctx);
	header_size := [2]f32{rect.size.x, header_height};
	header_layout := Layout {
		rect = util.Rect{
			pos = rect.pos,
			size = header_size,
		},
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
			rect = util.Rect
			{
				pos = rect.pos + [2]f32{0, header_height},
				size = [2]f32{rect.size.x, rect.size.y - header_height},
			},
			direction = [2]f32{0, 1},
		};
		
		add_layout_to_group(ui_ctx, body_layout);
	}

	layout_draw_rect(ui_ctx, {}, {}, Color{0.5, 0.5, 0.5, 0.3}, 0);
	header_outline_rect := current_layout(ui_ctx).rect;
	header_outline_rect.pos -= {1, 1};
	header_outline_rect.size += {2, 2};
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
	if draw_content
	{
		layout_draw_rect(ui_ctx, {}, {}, Color{1, 0, 0, 0.8}, 0);
		header_outline_rect.size.y += current_layout(ui_ctx).rect.size.y;
	}
	rect_border(&ui_ctx.draw_list, header_outline_rect, {0, 0, 0, 1}, 1);
	return;
}
