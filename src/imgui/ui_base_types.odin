package imgui;

UI_Vec :: [2]int;

UI_Rect :: struct
{
	pos, size: UI_Vec,
}

UV_Vec :: [2]f32;

UV_Rect :: util.Rect;

GPU_Rect :: struct
{
	pos, size : [2]i32,
}

Color :: render.Color;

UI_ID :: distinct uint;

Anchor :: struct
{
	min, max: UV_Vec,
	left, top, right, bottom: int,
}

Padding :: struct
{
	top_left: UI_Vec,
	bottom_right: UI_Vec,
}

Alignment :: struct
{
	horizontal: Horizontal_Alignment,
	vertical: Vertical_Alignment,
}

Vertical_Alignment :: enum
{
	Top,
	Middle,
	Bottom,
}

Horizontal_Alignment :: enum
{
	Left,
	Right,
	Center,
}

Corner_Radius :: union
{
	int,
	f32,
}

Direction :: enum
{
	Vertical,
	Horizontal,
}

Unit :: enum
{
	Pixels,
	Ratio,
}

Sub_Rect :: struct
{
	rect: UI_Rect,
	anchor: UV_Vec,
	pivot: UV_Vec,
}

Child_Rect :: union
{
	Sub_Rect,
	Padding,
}

Rect_Hierarchy :: [dynamic] struct{rect: Child_Rect, parent: int}
