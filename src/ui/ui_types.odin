package ui

import "../input"
import "../render"
import "../util"
import "../container"

INDEX_BUFFER_SIZE :: 50000;
SSBO_SIZE :: 10000;

Render_System :: struct
{
    current_texture: render.Texture_Handle,

    shader: u32,
    //screen_size_attrib: i32,
	//texture_attrib: i32,
    vao: u32,
    element_buffer: u32,
	primitive_buffer: u32,
	ubo: u32,
}

UI_Vec :: [2]int;

UI_Rect :: struct
{
	pos, size: UI_Vec,
}

UV_Vec :: [2]f32;

UV_Rect :: util.Rect; 

Rect_Command :: struct
{
	rect: UI_Rect,
	uv_clip: util.Rect,
	using theme: Rect_Theme,
	texture_id: u64,
}

GPU_Rect_Command :: struct
{
	pos, size : [2]i32,
	uv_pos, uv_size : [2]f32,
	color: u32,
	border_color: u32,
	border_thickness: i32,
	corner_radius: i32,
	texture_id: u64,
	clip_index: i32,
}

GPU_Rect :: struct
{
	pos, size : [2]i32,
}

Draw_Command_Data :: struct
{
	rect: Rect_Command,
	clip_index: int,
}

Draw_Command_List :: struct
{
	commands: [dynamic]GPU_Rect_Command,
	index: [dynamic]u32,
	rect_command_count: int,
	clips: [dynamic]UI_Rect,
	clip_stack: [dynamic]int,
}

Ubo_Data :: struct
{
	screen_size: [2]i32,
	padding: [2]f32,
};

UIID :: distinct string;
Color :: render.Color;

Anchor :: struct
{
	min, max: UV_Vec,
	left, top, right, bottom: int,
}

Padding :: struct
{
	top_left: [2]int,
	bottom_right: [2]int,
}

Rect_Draw_Command :: struct
{
	using rect: UI_Rect,
	uv_rect: util.Rect,
	texture: render.Texture_Handle,
	color: Color,
	corner_radius: int,
}

Clip_Draw_Command :: struct
{
	using rect: util.Rect,
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
	Clip_Draw_Command,
}

Draw_List :: [dynamic]Draw_Command;

Layout :: struct
{
	using rect: UI_Rect,
	cursor: int,
	direction: [2]int,
	draw_commands: [dynamic]Layout_Draw_Command,
}

Layout_Stack :: [dynamic]Layout;

Input_State_Data :: struct
{
	drag_target: UI_ID,
	cursor_pos: UI_Vec,
	last_cursor_pos: UI_Vec,
	drag_amount: UI_Vec,
	delta_drag: UI_Vec,
	cursor_state: Cursor_Input_State,
}

Element_State :: bit_set[Interaction_Type];

Interaction_Type :: enum u8 {
	Hover,
	Press,
	Click,
	Drag,
}

Cursor_Input_State :: enum u8 {
	Normal,
	Press,
	Down,
	Drag,
	Click_Release,
	Drag_Release,
}

Interactions :: bit_set[Interaction_Type];

UI_ID :: distinct uint;

UI_Element :: struct
{
	using rect: UI_Rect,
	id: UI_ID,
}

Content_Size_Fitter :: struct
{
	rect: UI_Rect,
	layout_index_in_stack: int,
}

UI_Context :: struct
{
	elements_under_cursor: map[Interaction_Type]UI_ID,
	next_elements_under_cursor: map[Interaction_Type]UI_ID,
	draw_list: Draw_List,
	input_state: Input_State_Data,
	current_element: UI_Element,
	current_font: ^render.Font,
	layout_stack: Layout_Stack,
	font_atlas: render.Font_Atlas,
	sprite_table: ^container.Table(render.Sprite),
	editor_config: Editor_Config,
	renderer: Render_System,
	ui_draw_list: Draw_Command_List,
	current_theme: UI_Theme,
	content_size_fitters: [dynamic]Content_Size_Fitter,
}

Drag_State :: struct
{
	drag_last_pos: UI_Vec,
	dragging: bool,
	drag_offset: UI_Vec,
}

Window_State :: struct
{
	drag_state: Drag_State,
	rect: UI_Rect,
	folded: bool,
	scroll: int,
	
	last_frame_height: int,
}

Editor_Config :: struct
{
	line_height: int,
	
}

UI_Render_State :: struct
{
    shader: u32,

    screenSizeAttrib: i32,

    vao: u32,
	ssbo: u32,
    elementBuffer: u32,
    default_texture: u32,
}

UI_Render_System :: struct
{
    render_state: UI_Render_State,
    current_texture: render.Texture_Handle,
}

Color_Picker_Mode :: enum
{
	rgb,
}

Color_Picker_State :: struct
{
	mode: Color_Picker_Mode,
}

Unit :: enum
{
	Pixels,
	Ratio,
}

Slider_Direction :: enum
{
	Vertical,
	Horizontal,
}

Corner_Radius :: union
{
	int,
	f32,
}

Horizontal_Alignment :: enum
{
	Left,
	Right,
	Center,
}

Rect_Theme :: struct
{
	fill_color: Color,
	border_color: Color,
	border_thickness: int,
	corner_radius: Corner_Radius,
}

Button_Theme :: struct
{
	default_theme: Rect_Theme,
	hovered_theme: Rect_Theme,
	clicked_theme: Rect_Theme,
}

Window_Theme :: struct
{
	header_color: Color,
	background_color: Color,
}

Slider_Theme :: struct
{
	background_theme: Rect_Theme,
	foreground_theme: Button_Theme,
}

UI_Theme :: struct
{
	button: Button_Theme,
	window: Window_Theme,
	slider: Slider_Theme,
}
