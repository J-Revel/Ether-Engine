package render

import "../util"
import "core:log"

// TODO : should use ints instead of f32
init_atlas :: proc(using atlas: ^Atlas_Tree, available_size: [2]f32)
{
	root_node := Atlas_Tree_Node{rect = {size = available_size}, level = 0};
	append(&nodes, root_node);
	append(&available_spaces, 0);
}

allocate_rect :: proc(using atlas: ^Atlas_Tree, size: [2]f32) -> (rect: util.Rect, success: bool)
{
	for index, available_space_index in available_spaces
	{
		log.info(size, nodes[index].rect.size);
		if size.x <= nodes[index].rect.size.x && size.y <= nodes[index].rect.size.y
		{
			split_pack_node(atlas, index, size);
			ordered_remove(&available_spaces, available_space_index);
			return nodes[index].rect, true;
		}
	}
	return {}, false;
}

split_pack_node :: proc(using atlas: ^Atlas_Tree, index: int, size: [2]f32)
{
	to_split_node := &atlas.nodes[index];
	to_split_rect := to_split_node.rect;

	left_child_index := util.append_and_get_index(&nodes);
	right_child_index := util.append_and_get_index(&nodes);

	to_split_node.left_child_index = left_child_index;
	to_split_node.right_child_index = right_child_index;

	left_child_node := &nodes[left_child_index];
	right_child_node := &nodes[right_child_index];

	left_child_node.level = to_split_node.level + 1;
	right_child_node.level = to_split_node.level + 1;

	append(&available_spaces, left_child_index);
	append(&available_spaces, right_child_index);

	switch to_split_node.level % 2
	{
		case 0:
			left_child_node.rect = to_split_node.rect;
			left_child_node.rect.size.x = size.x;
			left_child_node.rect.size.y = to_split_node.rect.size.y - size.y;
			left_child_node.rect.pos.y += size.y;

			right_child_node.rect = to_split_node.rect;
			right_child_node.rect.size.x = to_split_node.rect.size.x - size.x;
			right_child_node.rect.pos.x += size.x;
			
		case 1:
			left_child_node.rect = to_split_node.rect;
			left_child_node.rect.size.x = to_split_node.rect.size.x - size.x;
			left_child_node.rect.size.y = size.y;
			left_child_node.rect.pos.x += size.x;

			right_child_node.rect = to_split_node.rect;
			right_child_node.rect.size.y = to_split_node.rect.size.y - size.y;
			right_child_node.rect.pos.y += size.y;
	}
	to_split_node.rect.size = size;
}
