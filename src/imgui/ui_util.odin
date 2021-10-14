package imgui;

scale_ui_vec_2f :: proc(v: UI_Vec, scale: [2]f32) -> (result: UI_Vec)
{
	result.x = int(f32(v.x) * scale.x);
	result.y = int(f32(v.y) * scale.y);
	return;
}

scale_ui_vec_scal :: proc(v: UI_Vec, scale: f32) -> (result: UI_Vec)
{
	result.x = int(f32(v.x) * scale);
	result.y = int(f32(v.y) * scale);
	return;
}

scale_ui_vec :: proc
{
	scale_ui_vec_scal,
	scale_ui_vec_2f,
}

compute_child_rect :: proc(parent: UI_Rect, child: Child_Rect) -> UI_Rect
{
	switch child_data in child
	{
		case Sub_Rect:
			anchor_pos := parent.pos + parent.size * child_data.anchor;
			pivot_offset := child_data.rect.size * child_data.pivot;
			pos := anchor_pos - pivot_offset;
			size := child_rect.size;
			return UI_Rect{pos, size};
		case Padding:
			return UI_rect{parent.pos + child.top_left, parent.size - child.top_left - child.bottom_right};
	}
}