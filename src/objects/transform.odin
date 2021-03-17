package prefab

import "core:log"
import "core:strings"
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

get_transform_absolute :: proc(transform_id: Transform_Handle) -> (pos: [2]f32, angle: f32, scale: f32)
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
	previous_elements[parent_next_element-1] = new_element_index;
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

	next_elements[previous_index-1] = next_index;
	next_elements[element_index-1] = next_elements[next_index-1];
	next_elements[next_index-1] = element_index;
	previous_elements[next_index-1] = previous_index;
	previous_elements[element_index-1] = next_index;
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

	previous_elements[next_index-1] = previous_index;
	previous_elements[element_index-1] = previous_elements[previous_index-1];
	previous_elements[previous_index-1] = element_index;
	next_elements[previous_index-1] = next_index;
	next_elements[element_index-1] = previous_index;
}