package ui

import "../input"

UIID :: distinct string;
Color :: [4]f32;

UI_Element :: struct
{
	pos: [2]f32,
	size: [2]f32
}

UI_Anchor :: struct
{
	min, max: [2]f32,
	left, top, right, bottom: f32,
}

Padding :: struct
{
	left, top, right, bottom: f32
}

Rect_Draw_Command :: struct
{
	pos: [2]f32,
	size: [2]f32,
	color: [4]f32,
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

Layout_Direction :: enum
{
	Horizontal,
	Vertical,
}

Layout :: struct
{
	pos, size: [2]f32,
	direction: Layout_Direction,
	cursor: [2]f32,
}

Layout_Group :: struct
{
	layouts: [dynamic]Layout,
	cursor: int,
}

Layout_Stack :: [dynamic]Layout_Group;

UI_Context :: struct
{
	draw_list: Draw_List,
	state_storage: map[UIID]int,

	mouse_pos: [2]f32,
	mouse_click: bool,
	hovered_element: uintptr,
	next_hovered_element: uintptr,
	current_element: uintptr,
	current_element_pos: [2]f32,
	current_element_size: [2]f32,
	layout_stack: Layout_Stack,
}