package ui

import "../input"
import "../render"
import "../util"
import "../container"

UIID :: distinct string;
Color :: [4]f32;

Anchor :: struct
{
	min, max: [2]f32,
	left, top, right, bottom: f32,
}

Padding :: struct
{
	top_left: [2]f32,
	bottom_right: [2]f32,
}

Rect_Draw_Command :: struct
{
	using rect: util.Rect,
	clip: util.Rect,
	texture: render.Texture_Handle,
	color: [4]f32,
}

Layout_Draw_Command :: struct
{
	final_cmd: ^Rect_Draw_Command,
	anchor: Anchor,
	padding: Padding,
}

Draw_Command :: union
{
	Rect_Draw_Command,
}

Draw_List :: [dynamic]Draw_Command;

Element_State :: enum
{
	Normal, Hovered, Clicked
}

Layout :: struct
{
	pos, size: [2]f32,
	direction: [2]f32,
	used_rect: util.Rect,
	padding: Padding,
	cursor: f32,
	draw_commands: [dynamic]Layout_Draw_Command,
}

Layout_Group :: struct
{
	layouts: [dynamic]Layout,
	cursor: int,
}

Layout_Stack :: [dynamic]Layout_Group;

Input_State :: struct
{
	mouse_states: [3]input.Key_State,
	cursor_pos: [2]f32,
}

UI_Context :: struct
{
	draw_list: Draw_List,
	input_state: Input_State,
	hovered_element: uintptr,
	next_hovered_element: uintptr,
	current_element: uintptr,
	current_element_pos: [2]f32,
	current_element_size: [2]f32,
	layout_stack: Layout_Stack,
	font_atlas: render.Font_Atlas,
	sprite_table: ^container.Table(render.Sprite),
}

Drag_State :: struct
{
	drag_last_pos: [2]f32,
	dragging: bool,
	drag_offset: [2]f32,
}

Window_State :: struct
{
	drag_state: Drag_State,
	rect: util.Rect,
	folded: bool,
}
