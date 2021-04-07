package ui

import "core:fmt"
import "../render"

label :: proc(ctx: ^UI_Context, str: string, color: Color = {1, 1, 1, 1}, location := #caller_location) -> (state: Element_State)
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
	state = ui_element(allocated_space, ctx, location);
	first_line_pos := ctx.current_element_pos + [2]f32{0, line_height};
	for line, index in lines
	{
		text(line, color, first_line_pos + [2]f32{0, f32(line_height) * f32(index)}, ctx.current_font, ctx);
	}
	return state;
}


drag_int :: proc(ctx: ^UI_Context, drag_cache: ^Drag_State, value: ^int, location := #caller_location)
{
	parent_layout := current_layout(ctx)^;
	widget_rect := allocate_element_space(ctx, {0, f32(ctx.editor_config.line_height)});
	new_layout := Layout {
		pos = widget_rect.pos, size = widget_rect.size,
		direction = {1, 0}
	};
	push_layout_group(ctx);
	add_layout_to_group(ctx, new_layout);
	label(ctx, "drag editor ", {1, 1, 1, 1});
	#partial switch label(ctx, fmt.tprint(value^), {1, 1, 1, 1}, location)
	{
		case .Hovered:
			element_draw_rect(default_anchor, {}, render.Color{1, 1, 0, 1}, ctx);
		case .Normal:
	}
	pop_layout_group(ctx);
}
