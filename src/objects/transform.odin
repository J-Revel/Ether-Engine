package prefab

import "core:log"
import "core:strings"
import "core:math"

import "../container"

Transform :: struct
{
	parent: container.Handle(Transform),
	pos: [2]f32, // position relative to parent
	scale: f32,
	angle: f32
}

Transform_Handle :: container.Handle(Transform);
Transform_Table :: container.Table(Transform);
Transform_Hierarchy_Handle :: container.Handle(int);



Transform_Hierarchy :: struct
{
	element_index_table: container.Table(int),
	transforms: [dynamic]Transform,
	names: [dynamic]string,
	levels: [dynamic]int,
	next_elements: [dynamic]int,
	previous_elements: [dynamic]int,
	handles: [dynamic]Transform_Hierarchy_Handle,
	first_element_index: int,
	last_element_index: int,
}

get_transform_absolute_old :: proc(transform_id: Transform_Handle) -> (pos: [2]f32, angle: f32, scale: f32)
{
	scale = 1;
	for cursor := transform_id; cursor.id > 0;
	{
		cursor_data := container.handle_get(cursor);
		if cursor_data != nil
		{
			pos += cursor_data.pos;
			cursor = cursor_data.parent;
			scale *= cursor_data.scale;
		}
		else
		{
			cursor = {};
		}
	}
	return;
}

transform_hierarchy_add_root :: proc(using hierarchy: ^Transform_Hierarchy, transform: Transform, name: string) -> Transform_Hierarchy_Handle
{
	new_element_index := len(transforms) + 1;
	result, ok := container.table_add(&element_index_table, new_element_index);
	assert(ok);
	previous_element_index := 0;
	if last_element_index > 0
	{
		next_elements[last_element_index - 1] = new_element_index;
		previous_element_index = last_element_index;
	}

	append(&transforms, transform);
	append(&next_elements, 0);
	append(&previous_elements, previous_element_index);
	append(&levels, 0);
	append(&names, strings.clone(name));
	append(&handles, result);
	log.info(next_elements);

	last_element_index = new_element_index;
	if first_element_index <= 0 do first_element_index = new_element_index;
	return result;
}

transform_hierarchy_add_leaf :: proc(using hierarchy: ^Transform_Hierarchy, transform: Transform, parent: Transform_Hierarchy_Handle, name: string) -> Transform_Hierarchy_Handle
{
	new_element_index := len(transforms)+1;
	result, ok := container.table_add(&element_index_table, new_element_index);
	assert(ok);
	parent_index := container.table_get(&element_index_table, parent)^;
	assert(parent_index > 0);

	append(&transforms, transform);

	parent_next_element := next_elements[parent_index-1];
	if parent_next_element > 0 do previous_elements[parent_next_element-1] = new_element_index;
	append(&next_elements, parent_next_element);
	append(&previous_elements, parent_index);
	append(&levels, levels[parent_index-1] + 1);
	append(&names, strings.clone(name));
	append(&handles, result);

	next_elements[parent_index-1] = new_element_index;
	return result;
}

transform_hierarchy_move_element_down :: proc(using hierarchy: ^Transform_Hierarchy, element: Transform_Hierarchy_Handle)
{
	element_index := container.table_get(&element_index_table, element)^;
	previous_index := previous_elements[element_index-1];
	next_index := next_elements[element_index-1];

	if next_index <= 0 do return;

	next_next := next_elements[next_index-1];

	if next_next > 0 do previous_elements[next_next-1] = element_index;
	else do last_element_index = element_index;

	if previous_index > 0 do next_elements[previous_index-1] = next_index;
	else do first_element_index = next_index;
	next_elements[element_index-1] = next_elements[next_index-1];
	next_elements[next_index-1] = element_index;
	previous_elements[next_index-1] = previous_index;
	previous_elements[element_index-1] = next_index;

	transform_hierarchy_fix_levels(hierarchy);
}

transform_hierarchy_move_element_up :: proc(using hierarchy: ^Transform_Hierarchy, element: Transform_Hierarchy_Handle)
{
	element_index := container.table_get(&element_index_table, element)^;
	previous_index := previous_elements[element_index-1];
	next_index := next_elements[element_index-1];

	if previous_index <= 0 do return;

	previous_previous := previous_elements[previous_index-1];

	if previous_previous > 0 do next_elements[previous_previous-1] = element_index;
	else do first_element_index = element_index;

	if next_index > 0 do previous_elements[next_index-1] = previous_index;
	else do last_element_index = previous_index;
	previous_elements[element_index-1] = previous_elements[previous_index-1];
	previous_elements[previous_index-1] = element_index;
	next_elements[previous_index-1] = next_index;
	next_elements[element_index-1] = previous_index;

	transform_hierarchy_fix_levels(hierarchy);
}

// TODO : actually release the slot of the removed element
transform_hierarchy_remove :: proc(using hierarchy: ^Transform_Hierarchy, element: Transform_Hierarchy_Handle)
{
	element_index := container.table_get(&element_index_table, element)^;
	container.handle_remove(element);
	previous_index := previous_elements[element_index-1];
	next_index := next_elements[element_index-1];

	if previous_index > 0
	{
		next_elements[previous_index-1] = next_index;
	}
	else 
	{
		first_element_index = next_index;
	}
	if next_index > 0
	{
		previous_elements[next_index-1] = previous_index;
	}
	else
	{
		last_element_index = previous_index;
	}
	transform_hierarchy_fix_levels(hierarchy);
}

transform_hierarchy_add_level :: proc(using hierarchy: ^Transform_Hierarchy, element: Transform_Hierarchy_Handle, delta_level: int)
{
	element_index := container.table_get(&element_index_table, element)^;
	previous_index := previous_elements[element_index - 1];
	levels[element_index - 1] += delta_level;
	if levels[element_index - 1] < 0 do levels[element_index - 1] = 0;
	if previous_index <= 0 do levels[element_index - 1] = 0;
	else if levels[previous_index - 1] + 1 < levels[element_index - 1]
	{
		levels[element_index - 1] = levels[previous_index - 1] + 1;
	}
	transform_hierarchy_fix_levels(hierarchy);
}

transform_hierarchy_fix_levels :: proc(using hierarchy: ^Transform_Hierarchy)
{
	cursor := first_element_index;
	if levels[cursor - 1] > 0 do levels[cursor - 1] = 0;
	for cursor > 0 && next_elements[cursor - 1] > 0
	{
		next_element := next_elements[cursor - 1];
		if levels[next_element-1] > levels[cursor - 1] + 1
		{
			levels[next_element - 1] = levels[cursor - 1] + 1;
		}
		cursor = next_element;
	}
}

get_transform_parent :: proc(using hierarchy: ^Transform_Hierarchy, transform_handle: Transform_Hierarchy_Handle) -> Transform_Hierarchy_Handle
{
	cursor := container.table_get(&element_index_table, transform_handle)^;
	element_level := levels[cursor-1];
	for ;cursor > 0;cursor = previous_elements[cursor-1] 
	{
		if levels[cursor-1] < element_level do return handles[cursor-1];
	}
	return {};
}

get_absolute_transform :: proc(using hierarchy: ^Transform_Hierarchy, transform_handle: Transform_Hierarchy_Handle) -> Transform
{
	result: Transform = {scale = 1};
	element_index := container.table_get(&element_index_table, transform_handle)^;
	parent_list := make([]int, levels[element_index-1] + 1, context.temp_allocator);

	for cursor := element_index; cursor > 0; cursor = previous_elements[cursor-1]
	{
		level := levels[cursor - 1];
		if level < len(parent_list) && parent_list[level] == 0 do parent_list[level] = cursor;
	}

	for i in 0..<len(parent_list)
	{
		parent_transform := transforms[parent_list[i] - 1];

		local_right: [2]f32 = {math.cos(result.angle), math.sin(result.angle)};
		using math;
		local_up: [2]f32 = {math.cos(result.angle + PI / 2), math.sin(result.angle + PI / 2)};
		result.pos += parent_transform.pos.x * local_right * result.scale;
		result.pos += parent_transform.pos.y * local_up * result.scale;
		result.angle += parent_transform.angle;
		result.scale *= parent_transform.scale;
	}

	return result;
}