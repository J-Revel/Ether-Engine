package editor
import "../container"
import "../render"
import win32 "core:sys/windows"
import "core:os"
import "../util"
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

// Same data as Sprite, except name is a []u8 to be usable in editor
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
	editor_rect: util.Rect,
	texture_rect: util.Rect,
	mouse_pos: [2]f32,
}

/*----------------------------------------------
				Prefab Editor
------------------------------------------------*/

Prefab_Field :: struct
{
	using component_field: Component_Field,
	component_index: int,
}

Component_Field :: struct
{
	name: string,
	offset_in_component: uintptr,
	type_id: typeid
}

Prefab_Editor_Input :: struct
{
	using data: objects.Prefab_Input,
	display_value: rawptr,
}

Editor_Prefab :: struct
{
	prefab_tables: ^objects.Named_Table_List,
	components: []objects.Component_Model,
	inputs: []Prefab_Editor_Input,
}


Editor_Type_Callback :: #type proc
(
	prefab: Editor_Prefab, 
	field: Prefab_Field,
	scene_database: ^container.Database
);

Gizmo_Drag_Action :: enum
{
	Translate_X,
	Translate_Y,
	Rotate,
}

Gizmo_State :: struct
{
	edited_component: int,
	dragging: bool,
	drag_start_pos: [2]int,
	drag_action: Gizmo_Drag_Action,
}

Transform_Hierarchy_Editor_State :: struct
{
	selected_index: int,
}

Prefab_Editor_State :: struct
{
	scene: gameplay.Scene,
	components: [dynamic]objects.Component_Model,
	inputs: [dynamic]Prefab_Editor_Input,
	transform_hierarchy: objects.Transform_Hierarchy,
	
	components_history: [dynamic][]objects.Component_Model,
	component_editor_callbacks: Editor_Callback_List,
	input_types: [dynamic]objects.Prefab_Input,
	z_down: bool,
	allocated_data: [dynamic]rawptr,
	ref_input_popup_field: Prefab_Field,
	transform_editor_state: Transform_Hierarchy_Editor_State,

	editor_database: container.Database,
}

/*----------------------------------------------
				Anim Editor
------------------------------------------------*/

Curve_Editor_State :: struct
{
	scrolling: [2]f32,
	dragged_point: int,
	dragging: bool,
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
