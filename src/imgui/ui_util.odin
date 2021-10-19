package custom_imgui;

import "core:mem"
import "core:strings"
import "core:hash"

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

filling_child_rect :: proc() -> Child_Rect
{
	return Child_Rect {
		position = { padding = {{0, 0}, {0, 0}} },
		anchor_min = {0, 0},
		anchor_max = {1, 1},
		pivot = {0, 0},
	};
}

compute_child_rect :: proc(parent: UI_Rect, child: Child_Rect) -> UI_Rect
{
	anchor_rect := UI_Rect {
		parent.pos + scale_ui_vec(parent.size, child.anchor_min),
		scale_ui_vec(parent.size, child.anchor_max - child.anchor_min),
	};
	padding_rect := UI_Rect	{
		pos = anchor_rect.pos + child.padding.top_left,
		size = anchor_rect.size - child.padding.top_left - child.padding.bottom_right,
	};
	placed_rect := UI_Rect {
		pos = anchor_rect.pos + child.placed.pos - scale_ui_vec(child.placed.size, child.pivot),
		size = child.placed.size,
	}

	return UI_Rect {
		pos = {
			anchor_rect.size.x == 0 ? placed_rect.pos.x : padding_rect.pos.x,
			anchor_rect.size.y == 0 ? placed_rect.pos.y : padding_rect.pos.y,
		},
		size = {
			anchor_rect.size.x == 0 ? placed_rect.size.x : padding_rect.size.x,
			anchor_rect.size.y == 0 ? placed_rect.size.y : padding_rect.size.y,
		},
	};
}

default_id :: proc(ui_id: UID, location := #caller_location) -> UID 
{
	if ui_id == 0 do return id_from_location(location);
	return ui_id;
}

id_from_location :: proc(location := #caller_location, additional_element_index: int = 0) -> UID
{
	file_path := transmute([]byte)location.file_path;
	to_hash := make([]byte, len(file_path) + size_of(int) * 2);
	mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path));
	location_line := location.line;
	additional_element_index : int = additional_element_index;
	mem.copy(&to_hash[len(file_path)], &location_line, size_of(int));
	mem.copy(&to_hash[len(file_path) + size_of(int)], &additional_element_index, size_of(int));
	return UID(hash.fnv32(to_hash));
}
