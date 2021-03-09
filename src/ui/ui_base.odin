package ui

import "../render"

current_ctx: ^Draw_Ctx;

rect :: proc(draw_list: ^Draw_List, pos: [2]f32, size: [2]f32, color: Color)
{
	append(draw_list, Rect_Draw_Command{pos, size, color});
}

button :: proc(id: UIID, draw_list: ^Draw_List, pos: [2]f32, size: [2]f32) -> bool
{
	render_color: render.Color= {1, 0, 0, 1};
	if id in current_ctx.state_storage
	{
		state := current_ctx.state_storage[id];
		hovered := state & 1;
		if hovered > 0 do render_color.y = 1;

	}
	rect(draw_list, pos, size, render_color);
	hovered := current_ctx.mouse_pos.x > pos.x 
		&& current_ctx.mouse_pos.y > pos.y
		&& current_ctx.mouse_pos.x < pos.x + size.x
		&& current_ctx.mouse_pos.y < pos.y + size.y;
	current_ctx.state_storage[id] = hovered ? 1 : 0;
	return false;
}

hover_button :: proc(cache: ^Button_Cache, pos: [2]f32, size: [2]f32, mouse_pos: [2]f32) -> (hovered: bool)
{
	cache.hovered = mouse_pos.x > pos.x 
		&& mouse_pos.y > pos.y
		&& mouse_pos.x < pos.x + size.x
		&& mouse_pos.y < pos.y + size.y;
	return cache.hovered;
}

default_button :: proc(draw_list: ^Draw_List, cache: ^Button_Cache, pos, size, mouse_pos: [2]f32) -> (clicked: bool)
{
	render_color: render.Color= {1, 0, 0, 1};

	if hover_button(cache, pos, size, mouse_pos)
	{
		render_color.y = 1;
	}
	
	rect(draw_list, pos, size, render_color);
	return false;
}

use_ctx :: proc(ctx: ^Draw_Ctx)
{
	current_ctx = ctx;
}

render_draw_list :: proc(draw_list: ^Draw_List, render_buffer: ^render.Color_Render_Buffer)
{
	vertices: [dynamic]render.Color_Vertex_Data;
	indices: [dynamic]u32;
	quad_index_list := [?]u32{0, 1, 2, 0, 2, 3};
	for draw_cmd in draw_list
	{
		switch cmd_data in draw_cmd
		{
			case Rect_Draw_Command:
				start_index := u32(len(vertices));
				vertice: render.Color_Vertex_Data = {cmd_data.pos, cmd_data.color};
				append(&vertices, vertice);
				vertice.pos.x = cmd_data.pos.x + cmd_data.size.x;
				append(&vertices, vertice);
				vertice.pos.y = cmd_data.pos.y + cmd_data.size.y;
				append(&vertices, vertice);
				vertice.pos.x = cmd_data.pos.x;
				append(&vertices, vertice);
				for index_offset in quad_index_list
				{
					append(&indices, start_index + index_offset);
				}
		}
	}
	render.push_mesh_data(render_buffer, vertices[:], indices[:]);
}