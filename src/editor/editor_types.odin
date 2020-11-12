package editor
import "../util/container"
import "../render"

Editor_State :: struct
{
	show_demo_window: bool,
	sprite_editor: Sprite_Editor_State,
}

Editor_Sprite_Data :: struct
{
	name: []u8,
	using data: render.Sprite_Data,
	render_color: u32,
	anchor_render_color: u32,
	render_corner_colors: [4]u32,
}

Sprite_Edit_Corner :: enum
{
	None, Min, Max
}

Sprite_Editor_Tool :: enum
{
	None, Move, Resize, Move_Anchor
}

Sprite_Tool_Data :: struct
{
	tool_type: Sprite_Editor_Tool,
	edited_sprite_index: int,
	last_mouse_pos: [2]f32,
	edit_sprite_h_corner: Sprite_Edit_Corner,
	edit_sprite_v_corner: Sprite_Edit_Corner,
}

Sprite_Editor_State :: struct
{
	texture_id: container.Handle(render.Texture),
	sprites_data: [dynamic]Editor_Sprite_Data,
	scale: f32,

	drag_start_pos: [2]f32,
	
	tool_data: Sprite_Tool_Data,
}