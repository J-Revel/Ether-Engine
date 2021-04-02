package render

allocate_rect :: proc(using bin_pack_tree: ^Bin_Pack_Tree, size: [2]int)
{
	new_element_index := len(nodes);
	append(&nodes, Bin_Pack_Node{});
}
