package platform_layer

import "../../input"
import "../../util"

/*******************************
 * COMMON PART OF PLATFORM LAYER
     * *****************************/

Window_Handle :: distinct int

File_Error :: enum {
    None,
    File_Not_Found,
}


Font_Metrics :: struct {
	render_height: f32,
	render_scale: f32,
	ascent: i32,
	descent: i32,
	linegap: i32,
}

Texture_Handle :: distinct int
Font_Handle :: distinct int

update_events: proc(window: Window_Handle, using input_state: ^input.State)

load_file: proc(file_path: string, allocator := context.allocator) -> ([]u8, File_Error)
get_window_size: proc(window: Window_Handle) -> [2]int
get_window_raw_ptr: proc(window: Window_Handle) -> rawptr

load_texture: proc(file_path: string, allocator := context.allocator) -> Texture_Handle
free_texture: proc(texture_handle: Texture_Handle)

load_font: proc(file_path: string, allocator := context.allocator) -> Font_Handle
free_font: proc(Texture_Handle)
get_font_metrics: proc(Font_Handle) -> Font_Metrics
compute_text_render_buffer: proc(text: string, theme: ^Text_Theme, allocator := context.allocator) -> Text_Render_Buffer

I_Rect :: util.Rect(i32)
F_Rect :: util.Rect(f32)

Rect_Theme :: struct {
	color: u32,
	border_color: u32,
	border_thickness: i32,
	corner_radius: i32,
}

Text_Theme :: struct {
	font: Font_Handle,
	size: f32,
	color: u32,
}

Rect_Command :: struct
{
	using rect: I_Rect,
	uv_pos, uv_size : [2]f32,
	using theme: Rect_Theme,
	clip_index: i32,
}

Glyph_Command :: struct
{
	using rect: F_Rect,
	character: rune,
	// uv_rect: F_Rect,
	color: u32,
	// texture_id: Texture_Handle,
	font: Font_Handle,
	clip_index: i32,
	threshold: f32,
}

Render_Command :: union {
	Rect_Command, Glyph_Command
}

Command_List :: struct {
	commands: [dynamic]Render_Command,
	clips: [dynamic]I_Rect,
}

Text_Render_Buffer :: struct {
	theme: ^Text_Theme,
	text: string,
	font: Font_Handle,
	render_rects: []F_Rect,
	caret_positions: [][2]f32,
	bounding_rect: I_Rect,
	offset: [2]f32,
}