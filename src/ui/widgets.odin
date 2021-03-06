package ui

import "core:log"
import "core:math/linalg"

import "core:fmt"
import "../render"
import "../util"

label :: proc(ctx: ^UI_Context, str: string, color: Color = 0xffffffff, location := #caller_location, additional_location_index: i32 = 0) -> (state: Element_State)
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
	text_color := render.rgb(255, 255, 255);
	if Interaction_Type.Drag in state
	{
		value^ += int(ctx.input_state.delta_drag.x);
	}
	if Interaction_Type.Drag in state || Interaction_Type.Press in state
	{
		text_color &= 0x00ffffff;
		element_draw_rect(ctx, default_anchor, {}, render.rgb(200, 200, 0), 5);
	}
	else if Interaction_Type.Hover in state 
	{
		text_color &= 0x00ffffff;;
		element_draw_rect(ctx, default_anchor, {}, render.rgb(255, 255, 0), 5);
	}
	new_layout := Layout {
		rect = widget_rect,
		direction = {1, 0},
	};
	push_layout_group(ctx);
	add_layout_to_group(ctx, new_layout);
	label(ctx, "drag editor ", text_color, location, additional_location_index + 1);
	label(ctx, fmt.tprint(value^), text_color, location, additional_location_index + 2);
	pop_layout_group(ctx);
}

h_slider :: proc(ctx: ^UI_Context, value: ^$T, min: T, max: T, location := #caller_location, additional_location_index: i32 = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {0, f32(ctx.editor_config.line_height)});
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = {pos = linalg.to_i32(widget_rect.pos), size = linalg.to_i32(widget_rect.size)},
		color = render.rgb(255, 255, 255),
		corner_radius = 5,
		border_thickness = 0,
	});
	value_ratio := f32(value^ - min) / f32(max - min);
	cursor_size : f32 = 20;
	cursor_rect := util.Rect {
		pos = widget_rect.pos + [2]f32{cursor_size / 2 + (widget_rect.size.x - cursor_size) * value_ratio - cursor_size / 2, 0},
		size = [2]f32{cursor_size, widget_rect.size.y},
	};
	cursor_state := ui_element(ctx, cursor_rect, {.Hover, .Drag}, location, 0);
	cursor_color: Color = render.rgb(200, 200, 200);
	if Interaction_Type.Drag in cursor_state
	{
		new_ratio := (ctx.input_state.cursor_pos.x - widget_rect.pos.x - cursor_size / 2) / (widget_rect.size.x - cursor_size);
		if new_ratio < 0 do new_ratio = 0;
		if new_ratio > 1 do new_ratio = 1;
		value^ = min + T(f32(max - min) * new_ratio);
		cursor_color = render.rgb(150, 150, 150);
	}
	else if Interaction_Type.Hover in cursor_state
	{
		cursor_color = render.rgb(170, 170, 170);
	}
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = {pos = linalg.to_i32(cursor_rect.pos), size = linalg.to_i32(cursor_rect.size)},
		color = cursor_color,
		corner_radius = 5,
		border_thickness = 1,
		border_color = render.rgb(128, 128, 128),
	});
}

v_slider :: proc(ctx: ^UI_Context, value: ^$T, min: T, max: T, width: f32 = 0, location := #caller_location, additional_location_index: i32 = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {width, 0});
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = {pos = linalg.to_i32(widget_rect.pos), size = linalg.to_i32(widget_rect.size)},
		color = render.rgb(255, 255, 255),
		corner_radius = 5,
		border_thickness = 0,
	});
	value_ratio := f32(value^ - min) / f32(max - min);
	cursor_size : f32 = 20;
	cursor_rect := util.Rect {
		pos = widget_rect.pos + [2]f32{0, cursor_size / 2 + (widget_rect.size.y - cursor_size) * value_ratio - cursor_size / 2},
		size = [2]f32{widget_rect.size.x, cursor_size},
	};
	cursor_state := ui_element(ctx, cursor_rect, {.Hover, .Drag}, location, 0);
	cursor_color: Color = render.rgb(200, 200, 200);
	if Interaction_Type.Drag in cursor_state
	{
		new_ratio := (ctx.input_state.cursor_pos.y - widget_rect.pos.y - cursor_size / 2) / (widget_rect.size.y - cursor_size);
		if new_ratio < 0 do new_ratio = 0;
		if new_ratio > 1 do new_ratio = 1;
		value^ = min + T(f32(max - min) * new_ratio);
		cursor_color = render.rgb(150, 150, 150);
	}
	else if Interaction_Type.Hover in cursor_state
	{
		cursor_color = render.rgb(170, 170, 170);
	}
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = {pos = linalg.to_i32(cursor_rect.pos), size = linalg.to_i32(cursor_rect.size)},
		color = cursor_color,
		corner_radius = 5,
		border_thickness = 1,
		border_color = render.rgb(128, 128, 128),
	});
}

window :: proc(using ctx: ^UI_Context, using state: ^Window_State, header_height: f32, location := #caller_location) -> (draw_content: bool)
{ 
	push_layout_group(ctx);
	header_size := [2]f32{rect.size.x, header_height};
	header_layout := Layout {
		rect = util.Rect{
			pos = rect.pos,
			size = header_size,
		},
		direction = [2]f32{-1, 0},
	};

	// Close button layout
	add_layout_to_group(ctx, header_layout);

	// Main Header Layout
	header_layout.direction.x = 1;
	add_layout_to_group(ctx, header_layout);

	draw_content = !state.folded;

	if draw_content
	{
		// Body Layout
		scrollbar_width: f32 = 30;
		body_layout := Layout {
			rect = util.Rect {
				pos = rect.pos + [2]f32{0, header_height},
				size = [2]f32{rect.size.x - scrollbar_width, rect.size.y - header_height},
			},
			direction = [2]f32{0, 1},
		};
		add_layout_to_group(ctx, body_layout);

		push_layout_group(ctx);
		if last_frame_height != 0
		{
			scrollbar_layout := Layout {
				rect = util.Rect {
					pos = rect.pos + [2]f32{body_layout.rect.size.x, header_height},
					size = [2]f32{scrollbar_width, rect.size.y - header_height},
				},
				direction = [2]f32{0, 1},
			};
			add_layout_to_group(ctx, scrollbar_layout);
			v_slider(ctx, &scroll, 0, 1, 0, location, 1);
		}
		pop_layout_group(ctx);
	}

	layout_draw_rect(ctx, {}, {}, render.rgba(128, 128 ,128, 80), 0);
	header_outline_rect := current_layout(ctx).rect;
	header_outline_rect.pos -= {1, 1};
	header_outline_rect.size += {2, 2};
	// Close button
	if drag_box(util.Rect{rect.pos, header_size}, &drag_state, ctx)
	{
		rect.pos += drag_state.drag_offset;
		drag_state.drag_offset = [2]f32{0, 0};
	}
	layout_button("close button", {header_height, header_height}, ctx); 
	next_layout(ctx);
	if layout_button("fold button", {header_height, header_height}, ctx)
	{
		state.folded = !state.folded;
	}
	next_layout(ctx);
	if draw_content
	{
		layout_draw_rect(ctx, {}, {}, render.rgba(255, 0, 0, 200), 0);
		header_outline_rect.size.y += current_layout(ctx).rect.size.y;
		scroll_content_rect := current_layout(ctx).rect;
		scroll_content_rect.size.y = state.last_frame_height;
		add_rect_command(&ctx.ui_draw_list, Rect_Command{
			rect = {pos = linalg.to_i32(scroll_content_rect.pos), size = linalg.to_i32(scroll_content_rect.size/2)},
			color = render.rgba(255, 255, 255, 100),
			corner_radius = 5,
			border_thickness = 0,
		});
		rect_border(&ctx.draw_list, scroll_content_rect, render.rgba(255, 255, 255, 100), 1);
		log.info(scroll_content_rect);
	}
	rect_border(&ctx.draw_list, header_outline_rect, render.rgb(0, 0, 0), 1);
	return;
}

window_end :: proc(using ctx: ^UI_Context, using state: ^Window_State)
{
	state.last_frame_height = current_layout(ctx).used_rect.size.y;
}
