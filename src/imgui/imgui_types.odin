package imgui

import "../util"
import "../input"
import sdl "vendor:sdl2"
import platform_layer "../platform_layer/base"

INDEX_BUFFER_SIZE :: 50000
SSBO_SIZE :: 10000

UID :: distinct uint

Texture_Format :: enum {
	R,
	RGB,
	RGBA,
}

Texture_Data :: struct {
	data: []u8,
	size: [2]int,
	texture_format: Texture_Format,
}

Texture_Handle :: distinct int

Renderer_Draw_Commands_Proc :: proc(renderer: ^Renderer, draw_list: ^platform_layer.Command_List)
Renderer_Free_Proc :: proc(renderer: ^Renderer)
Renderer_Load_Texture :: proc(renderer: ^Renderer, texture_data: ^Texture_Data) -> Texture_Handle

Renderer :: struct {
	render_draw_commands: Renderer_Draw_Commands_Proc,
	load_texture: Renderer_Load_Texture,
	free_renderer: Renderer_Free_Proc,
}

Vulkan_Render_System :: struct {

}

OpenGL_Render_System :: struct {
    shader: u32,
    vao: u32,
    element_buffer: u32,
	rect_primitive_buffer: u32,
	glyph_primitive_buffer: u32,
	ubo: u32,
	screen_size_attrib: i32,
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
	render_system: Renderer,
	input_state: ^input.State,
	command_list: platform_layer.Command_List,
	hovered_element: UID,
	focused_element: UID,
	next_hovered: UID,
	next_focused: UID,
	dragged_element: UID,
	dragged_element_data: rawptr,
	clip_stack: [dynamic]i32,
}

Texture :: struct
{
    path: string,
    texture_id: u32,
	bindless_id: u64,
	resident: bool,
    size: [2]int,
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
	default_theme: platform_layer.Rect_Theme,
	hovered_theme: platform_layer.Rect_Theme,
	clicked_theme: platform_layer.Rect_Theme,
}

Slider_Theme :: struct {
	background_theme: platform_layer.Rect_Theme,
	cursor_theme: Button_Theme,
	cursor_height: i32,
}

Scrollzone_Theme :: struct {
	slider_theme: Slider_Theme,
	background_theme: platform_layer.Rect_Theme,
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
	caret_theme: platform_layer.Rect_Theme,
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