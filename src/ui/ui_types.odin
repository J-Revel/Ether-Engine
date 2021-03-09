package ui

import "../input"

UIID :: distinct string;
Color :: [4]f32;

UI_Element :: struct
{
	pos: [2]f32,
	size: [2]f32
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

Draw_Ctx :: struct
{
	state_storage: map[UIID]int,
	mouse_pos: [2]f32,
}

Button_Cache :: struct
{
	hovered: bool
}