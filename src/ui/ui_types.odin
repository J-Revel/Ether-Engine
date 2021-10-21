package ui

import "../input"
import "../render"
import "../util"
import "../container"

/*
	TODO : different layers to implement properly
	render -> uses assets to do the actual rendering
	ui_elements -> uses Rect_Theme an Text_Theme and handles basic ui events
	widgets -> handles more complex ui elements, uses widget themes

	TODO : handle more primitives : gradients, nine slices
*/

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

// A command to draw a themed rect, as seen from the outside of the UI system
Rect_Command :: struct
{
	// rect is local to the layout => it will move with it if needed
	rect: UI_Rect,
	uv_clip: util.Rect,
	using theme: Rect_Theme,
	texture_id: u64,
}

// A rect command once it has been pushed, with 
Computed_Rect_Command :: struct
{
	using command: Rect_Command,
	clip_index: int,
	parent: int,
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

Draw_Command_List :: struct
{
	commands: [dynamic]Computed_Rect_Command,
	clips: [dynamic]UI_Rect,
	clip_stack: [dynamic]int,
}

GPU_Command_List :: struct
{
	commands: []GPU_Rect_Command,
	index: []u32,
	clips: []UI_Rect,
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
	top_left: UI_Vec,
	bottom_right: UI_Vec,
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
	final_cmd: ^Rect_Command,
	anchor: Anchor,
	padding: Padding,
}

Draw_Command :: union
{
	Rect_Draw_Command,
	Clip_Draw_Command,
}

// DEPRECATED
Draw_List :: [dynamic]Draw_Command;

Layout :: struct
{
	using rect: UI_Rect,
	cursor: int,
	direction: [2]int,
	draw_commands: [dynamic]^Computed_Rect_Command,
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
	max_padding: UI_Vec,
	directions: bit_set[UI_Direction],
}

Active_Widget_Data :: union
{
	u8,
	int,
	f32,
}

UI_Context :: struct
{
	elements_under_cursor: map[Interaction_Type]UI_ID,
	next_elements_under_cursor: map[Interaction_Type]UI_ID,
	draw_list: Draw_List,
	input_state: Input_State_Data,
	current_element: UI_Element,
	layout_stack: Layout_Stack,
	using font_loader: Font_Loader,
	sprite_table: ^container.Table(render.Sprite),
	editor_config: Editor_Config,
	renderer: Render_System,
	ui_draw_list: Draw_Command_List,
	current_theme: UI_Theme,
	content_size_fitters: [dynamic]Content_Size_Fitter,
	active_widget_data: Active_Widget_Data,
}

Font_Loader:: struct
{
	loaded_fonts: map[render.Font_Asset]^render.Font,
	font_atlas: render.Font_Atlas,
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

UI_Direction :: enum
{
	Vertical,
	Horizontal,
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
	text: Text_Themes,
	number_editor: Number_Editor_Theme,
}

Text_Themes :: struct
{
	default: Text_Theme,
	title: Text_Theme,
}

Text_Theme :: struct
{
	font_asset: render.Font_Asset,
	color: Color,
}

Number_Editor_Theme :: struct
{
	text: ^Text_Theme,
	buttons: ^Button_Theme,
	height: int,
	button_width: int,
}

Theme_Editor_State :: struct
{
	fold_states: map[UI_ID]bool,
}
