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
		allocated_length = render.get_text_render_size(ctx.current_font, str);
	}
	allocated_space := allocate_element_space(ctx, [2]int{allocated_length, int(f32(len(lines)) * line_height)});

	first_line_pos := allocated_space.pos + UI_Vec{0, int(line_height)};
	for line, index in lines
	{
		text(line, color, first_line_pos + UI_Vec{0, int(line_height * f32(index))}, ctx.current_font, ctx);
	}
	
	return state;
}


drag_int :: proc(ctx: ^UI_Context, value: ^int, location := #caller_location, additional_location_index: i32 = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {0, int(ctx.editor_config.line_height)});
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
	push_layout(ctx, new_layout);
	label(ctx, "drag editor ", text_color, location, additional_location_index + 1);
	label(ctx, fmt.tprint(value^), text_color, location, additional_location_index + 2);
	pop_layout(ctx);
}

h_slider :: proc(ctx: ^UI_Context, value: ^$T, min: T, max: T, location := #caller_location, additional_location_index: i32 = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {0, int(ctx.editor_config.line_height)});
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = widget_rect,
		theme = {
			fill_color = render.rgb(255, 255, 255),
			corner_radius = 5,
			border_thickness = 0,
		},
	});
	value_ratio := f32(value^ - min) / f32(max - min);
	cursor_size : int= 20;
	cursor_rect := UI_Rect {
		pos = widget_rect.pos + UI_Vec{cursor_size / 2 + int(f32(widget_rect.size.x - cursor_size) * value_ratio) - cursor_size / 2, 0},
		size = UI_Vec{cursor_size, widget_rect.size.y},
	};
	cursor_state := ui_element(ctx, cursor_rect, {.Hover, .Drag}, location, 0);
	cursor_color: Color = render.rgb(200, 200, 200);
	if Interaction_Type.Drag in cursor_state
	{
		new_ratio := f32(ctx.input_state.cursor_pos.x - widget_rect.pos.x - cursor_size / 2) / f32(widget_rect.size.x - cursor_size);
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
		rect = cursor_rect,
		theme = {
			fill_color = cursor_color,
			corner_radius = 5,
			border_thickness = 1,
			border_color = render.rgb(128, 128, 128),
		},
	});
}

v_slider :: proc(ctx: ^UI_Context, value: ^$T, min: T, max: T, width: int = 0, location := #caller_location, additional_location_index: int = 0)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {width, 0});
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = widget_rect,
		theme = {
			fill_color = render.rgb(255, 255, 255),
			corner_radius = 5,
			border_thickness = 0,
		},
	});
	value_ratio := f32(value^ - min) / f32(max - min);
	cursor_size : int = 20;
	cursor_rect := UI_Rect {
		pos = widget_rect.pos + UI_Vec{0, cursor_size / 2 + int(f32(widget_rect.size.y - cursor_size) * value_ratio) - cursor_size / 2},
		size = UI_Vec{widget_rect.size.x, cursor_size},
	};
	cursor_state := ui_element(ctx, cursor_rect, {.Hover, .Drag}, location, 0);
	cursor_color: Color = render.rgb(200, 200, 200);
	if Interaction_Type.Drag in cursor_state
	{
		new_ratio := f32(ctx.input_state.cursor_pos.y - widget_rect.pos.y - cursor_size / 2) / f32(widget_rect.size.y - cursor_size);
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
		rect = cursor_rect,
		theme = {
			fill_color = cursor_color,
			corner_radius = 5,
			border_thickness = 1,
			border_color = render.rgb(128, 128, 128),
		},
	});
}

window :: proc(using ctx: ^UI_Context, using state: ^Window_State, header_height: int, location := #caller_location) -> (draw_content: bool)
{ 
	header_size := UI_Vec{rect.size.x, header_height};
	header_layout := Layout {
		rect = UI_Rect{
			pos = rect.pos,
			size = header_size,
		},
		direction = {-1, 0},
	};

	// Close button layout
	push_layout(ctx, header_layout);

	// Main Header Layout
	header_layout.direction.x = 1;
	pop_layout(ctx);
	push_layout(ctx, header_layout);

	draw_content = !state.folded;

	theme := current_theme.window;

	if draw_content
	{
		// Body Layout
		scrollbar_width := 30;
		body_layout := Layout {
			rect = UI_Rect {
				pos = rect.pos + UI_Vec{0, header_height},
				size = UI_Vec{rect.size.x - scrollbar_width, rect.size.y - header_height},
			},
			direction = {0, 1},
		};
		push_layout(ctx, body_layout);

		if last_frame_height != 0
		{
			scrollbar_layout := Layout {
				rect = UI_Rect {
					pos = rect.pos + UI_Vec{body_layout.rect.size.x, header_height},
					size = UI_Vec{scrollbar_width, rect.size.y - header_height},
				},
				direction = {0, 1},
			};
			push_layout(ctx, scrollbar_layout);
			v_slider(ctx, &scroll, 0, 1, 0, location, 1);
			pop_layout(ctx);
		}
		pop_layout(ctx);
	}

	layout_draw_rect(ctx, {}, {}, render.rgba(128, 128 ,128, 80), 0);
	header_outline_rect := current_layout(ctx).rect;
	header_outline_rect.pos -= {1, 1};
	header_outline_rect.size += {2, 2};
	// Close button
	if drag_box(UI_Rect{rect.pos, header_size}, &drag_state, ctx)
	{
		rect.pos += drag_state.drag_offset;
		drag_state.drag_offset = {0, 0};
	}
	button("close button", {header_height, header_height}, ctx); 
	//next_layout(ctx);
	if button("fold button", {header_height, header_height}, ctx)
	{
		state.folded = !state.folded;
	}
	//next_layout(ctx);
	if draw_content
	{
		push_clip(&ctx.ui_draw_list, layout_get_rect(ctx, {}, {}));
		layout_draw_rect(ctx, {}, {}, theme.fill_color, 0);
		header_outline_rect.size.y += current_layout(ctx).rect.size.y;
		scroll_content_rect := current_layout(ctx).rect;
		scroll_content_rect.size.y = state.last_frame_height;
		add_rect_command(&ctx.ui_draw_list, Rect_Command{
			rect = {pos = scroll_content_rect.pos, size = scroll_content_rect.size/2},
			theme = {
				fill_color = render.rgba(255, 255, 255, 100),
				corner_radius = 5,
				border_thickness = 0,
			},
		});
		rect_border(&ctx.draw_list, scroll_content_rect, render.rgba(255, 255, 255, 100), 1);
		//log.info(scroll_content_rect);
	}
	rect_border(&ctx.draw_list, header_outline_rect, render.rgb(0, 0, 0), 1);
	return;
}

window_end :: proc(using ctx: ^UI_Context, using state: ^Window_State)
{
	pop_clip(&ctx.ui_draw_list);
	// TODO : handle content height computation
	//state.last_frame_height = current_layout(ctx).used_rect.size.y;
}
