package editor;

import "core:fmt"
import "core:log"

import "../../libs/imgui"

import "../objects"

transform_hierarchy_editor :: proc(using hierarchy: ^objects.Transform_Hierarchy)
{
	imgui.separator();
	cursor := first_element_index;
	index: i32 = 0;
	imgui.push_id("transform hierarchy");
	for cursor > 0
	{
		imgui.push_id(index);
		imgui.text("");
		imgui.same_line(0, f32(20 * levels[cursor-1]));
		imgui.input_string("", &names[cursor-1]);
		imgui.same_line();
		if imgui.button("+")
		{
			objects.transform_hierarchy_add_leaf(hierarchy, {}, handles[cursor-1], "leaf transform");
		}
		imgui.same_line();
		if imgui.button("up")
		{
			objects.transform_hierarchy_move_element_up(hierarchy, handles[cursor-1]);
		}
		imgui.same_line();
		if imgui.button("down")
		{
			objects.transform_hierarchy_move_element_down(hierarchy, handles[cursor-1]);
		}
		cursor = next_elements[cursor-1];
		imgui.pop_id();
		index += 1;
	}

	for i in 0..<len(transforms)
	{
		imgui.text_unformatted(fmt.tprint(i, ":", previous_elements[i]-1, next_elements[i]-1));
	}
	if imgui.button("+")
	{
		objects.transform_hierarchy_add_root(hierarchy, {}, "root transform");
	}
	imgui.pop_id();
}