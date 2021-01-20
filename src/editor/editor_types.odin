package editor
import "../container"
import "../render"
import win32 "core:sys/windows"
import "core:os"
import "../geometry"
import "../objects"
import "../gameplay"
import "../animation"

Editor_State :: struct
{
	show_demo_window: bool,
	sprite_editor: Sprite_Editor_State,
	prefab_editor: Prefab_Editor_State,
	anim_editor: Anim_Editor_State,
}

/*----------------------------------------------
				Sprite Editor
------------------------------------------------*/

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
	file_selection_data: File_Selection_Data,
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

/*----------------------------------------------
				Prefab Editor
------------------------------------------------*/

Editor_Type_Callback :: #type proc
(
	using editor_state: ^Prefab_Editor_State, 
	using field: Component_Model_Field
);

Component_Model_Field :: struct
{
	name: string,
	component: ^objects.Component_Model,
	offset_in_component: uintptr,
	type_id: typeid,
}

Prefab_Editor_State :: struct
{
	scene: gameplay.Scene,
	using prefab: objects.Dynamic_Prefab,
	components_history: [dynamic][]objects.Component_Model,
	editor_type_callbacks: map[typeid]Editor_Type_Callback,
	input_types: [dynamic]objects.Prefab_Input_Type,
	z_down: bool,
}

/*----------------------------------------------
				Anim Editor
------------------------------------------------*/

Curve_Editor_State :: struct
{
	scrolling: [2]f32,
}

Anim_Editor_State :: struct
{
	anim_curve: animation.Dynamic_Animation_Curve(f32)
	curve_editor_state: Curve_Editor_State,
}

/*----------------------------------------------
				Folder Editor
------------------------------------------------*/

File_Search_State :: enum
{
	Stopped,
	Searching,
	Found,
}

Folder_Display_State :: struct
{
	current_path: string,
	files: []os.File_Info,
}

File_Filter_Type :: enum
{
	All,
	Show_With_Ext,
	Hide_With_Ext
}

File_Search_Config :: struct
{
	start_folder: string,
	filter_type: File_Filter_Type,
	extensions: []string,
	hide_folders: bool,
	can_create: bool,
	confirm_dialog: bool,
}

File_Selection_Data :: struct
{
	current_path: string,
	new_file_name: string,
	display_data: []os.File_Info
}