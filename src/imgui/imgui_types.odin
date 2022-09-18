package imgui

import "../render"
import "../util"
import "../input"

INDEX_BUFFER_SIZE :: 50000
SSBO_SIZE :: 10000

I_Rect :: util.Rect(i32)
F_Rect :: util.Rect(f32)

UID :: distinct uint

Render_System :: struct {
    current_texture: render.Texture_Handle,

    shader: u32,
    vao: u32,
    element_buffer: u32,
	rect_primitive_buffer: u32,
	glyph_primitive_buffer: u32,
	ubo: u32,
	screen_size_attrib: i32,
}

Rect_Theme :: struct {
	color: u32,
	border_color: u32,
	border_thickness: i32,
	corner_radius: i32,
	texture_id: u64,
}

Rect_Command :: struct
{
	pos, size : [2]i32,
	uv_pos, uv_size : [2]f32,
	using theme: Rect_Theme,
	clip_index: i32,
}

Glyph_Command :: struct
{
	pos, size: [2]f32,
	uv_pos, uv_size: [2]f32,
	color: u32,
	texture_id: u64,
	clip_index: i32,
	threshold: f32,
}

Command_List :: struct
{
	rect_commands: [dynamic]Rect_Command,
	glyph_commands: [dynamic]Glyph_Command,
	index: [dynamic]u32,
	clips: [dynamic]I_Rect,
}

Ubo_Data :: struct
{
	screen_size: [2]i32,
	padding: [2]f32,
}

Default_Dragged_Data :: struct($T: typeid) {
	drag_start_pos: [2]i32,
	drag_start_value: T,
}

UI_State :: struct
{
	render_system: Render_System,
	input_state: ^input.State,
	command_list: Command_List,
	hovered_element: UID,
	focused_element: UID,
	next_hovered: UID,
	next_focused: UID,
	dragged_element: UID,
	dragged_element_data: rawptr,
	clip_stack: [dynamic]i32,
	fonts: map[string]Packed_Font,
}

Packed_Font :: struct {
	render_height: f32,
	render_scale: f32,
	ascent: i32,
	descent: i32,
	linegap: i32,
	glyph_data: map[rune]Packed_Glyph_Data,
	atlas_texture: render.Texture,
}

Packed_Glyph_Data :: struct {
	rect: I_Rect,
	offset: [2]i32,
	advance: i32,
	left_side_bearing: i32,
}

Button_State :: input.Key_State

Text_Render_Buffer :: struct {
	theme: ^Text_Theme,
	text: string,
	render_rects: []F_Rect,
	caret_positions: [][2]f32,
	bounding_rect: I_Rect,
	offset: [2]f32,
}

Button_Theme :: struct {
	default_theme: Rect_Theme,
	hovered_theme: Rect_Theme,
	clicked_theme: Rect_Theme,
}

Slider_Theme :: struct {
	background_theme: Rect_Theme,
	cursor_theme: Button_Theme,
	cursor_height: i32,
}

Scrollzone_Theme :: struct {
	slider_theme: Slider_Theme,
	background_theme: Rect_Theme,
	bar_thickness: i32,
}

Text_Theme :: struct {
	font: string,
	size: f32,
	color: u32,
}

Text_Block_Theme :: struct {
	using text_theme: Text_Theme,
	alignment: [2]f32,
}

Text_Field_Theme :: struct {
	background_theme: Button_Theme,
	text_theme: Text_Block_Theme,
	caret_theme: Rect_Theme,
	caret_thickness: i32,
}

Window_Theme :: struct {
	scrollzone_theme: Scrollzone_Theme,
	header_thickness: i32,
	header_theme: Button_Theme,
	title_theme: Text_Theme,
}

Editor_Theme :: struct {
	button: Button_Theme,
	text_field: Text_Field_Theme,
	window: Window_Theme,
}