package editor
import "../util/container"
import "../render"
import win32 "core:sys/windows"
import "core:os"
import "../geometry"

Editor_State :: struct
{
	show_demo_window: bool,
	sprite_editor: Sprite_Editor_State,
}

Editor_Sprite_Data :: struct
{
	name: []u8,
	using data: render.Sprite_Data
}

Sprite_Edit_Corner :: enum
{
	None, Min, Max
}

Sprite_Editor_Tool :: enum
{
	None, Scroll, Selected, Move, Resize, Move_Anchor
}

Sprite_Tool_Data :: struct
{
	tool_type: Sprite_Editor_Tool,
	time: f32,
	edited_sprite_index: int,
	last_mouse_pos: [2]f32,
	edit_sprite_h_corner: Sprite_Edit_Corner,
	edit_sprite_v_corner: Sprite_Edit_Corner,
	last_tool: Sprite_Editor_Tool,
	moved: bool
}

Folder_Display_State :: struct
{
	current_path: string,
	files: []os.File_Info,
}

Sprite_Editor_Theme :: struct
{
	sprite_normal: u32,
	sprite_hovered: u32,
	sprite_selected: u32,
	sprite_gizmo: u32,
}

Sprite_Editor_State :: struct
{
	loaded_textures: container.Table(render.Texture),
	texture_id: container.Handle(render.Texture),
	sprites_data: [dynamic]Editor_Sprite_Data,
	scale: f32,

	last_mouse_pos: [2]f32,

	drag_start_pos: [2]f32,
	
	tool_data: Sprite_Tool_Data,
	searching_file: bool,
	folder_display_state: Folder_Display_State,
	drag_offset: [2]f32,
	theme: Sprite_Editor_Theme,
}

Sprite_Side :: enum
{
	Left, Right, Up, Down
}

Sprite_Editor_Render_Data :: struct
{
	editor_rect: geometry.Rect,
	texture_rect: geometry.Rect,
	mouse_pos: [2]f32,
}