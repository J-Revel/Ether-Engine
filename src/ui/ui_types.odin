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

UI_Rect :: struct
{
	pos, size: [2]i32,
}

Rect_Command :: struct
{
	rect: UI_Rect,
	clip: util.Rect,
	color: Color,
	border_color: Color,
	border_thickness: f32,
	corner_radius: f32,
	texture_id: u64,
}

Draw_Command_Data :: struct
{
	rect: Rect_Command,
}

Draw_Command_List :: struct
{
	commands: [dynamic]Draw_Command_Data,
	index: [dynamic]i32,
	rect_command_count: int,
}

Ubo_Data :: struct
{
	screen_size: [2]f32,
	padding: [2]f32,
};

UIID :: distinct string;
Color :: render.Color;

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
	color: Color,
	corner_radius: f32,
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
	using rect: util.Rect,
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

Input_State_Data :: struct
{
	drag_target: UI_ID,
	cursor_pos: [2]f32,
	last_cursor_pos: [2]f32,
	drag_amount: [2]f32,
	delta_drag: [2]f32,
	cursor_state: Cursor_Input_State,
}

Element_State :: bit_set[Interaction_Type];

Interaction_Type :: enum u8
{
	Hover,
	Press,
	Click,
	Drag,
}

Cursor_Input_State :: enum u8
{
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
	using rect: util.Rect,
	id: UI_ID,
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
	scroll: f32,
	last_frame_height: f32,
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
