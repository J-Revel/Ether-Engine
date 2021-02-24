package editor

import imgui "../imgui";
import "../render"
import "core:log"
import "core:strings"
import "../container"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:reflect"
import "../animation"
import "../gameplay"

import "../geometry"
import "../objects"

Sprite_Selection_Data :: struct
{
	using texture_selection_data: File_Selection_Data,
	selection_open: bool,
	texture: render.Texture_Handle,
}

sprite_selectors: map[string]Sprite_Selection_Data;

sprite_selector :: proc(scene: ^gameplay.Scene, selector_id: string, start_folder: string)
{
	if selector_id not_in sprite_selectors
	{
		sprite_selectors[selector_id] = {};
	}
	selection_data := &sprite_selectors[selector_id];
	if selection_data.texture.id == 0
	{
		search_config := File_Search_Config{
			start_folder = start_folder,
			filter_type = .Show_With_Ext,
			extensions = {".meta"},
		};
		found_path, search_state := file_selector_popup(selector_id, "Select Sprite", search_config);
		#partial switch search_state
		{
			case .Found:
				// TODO : load corresponding texture if not already in db (=> path = found_path - ".meta")
				texture_path := fmt.tprintf("%s.png", found_path[0:len(found_path)-5]);
				loaded_texture: render.Texture_Handle;
				it := container.table_iterator(&scene.textures);
				for texture, texture_handle in container.table_iterate(&it)
				{
					if texture.path == texture_path
					{
						loaded_texture = texture_handle;
						break;
					}
				}
				if loaded_texture.id <= 0
				{
					texture_data := render.load_texture(texture_path);
					texture_load_ok := false;
					loaded_texture, texture_load_ok = container.table_add(&scene.textures, texture_data);
				}
				names, sprites, success := render.load_sprites_data(found_path);
				if success
				{
					for name, index in names
					{
						for sprite_id in 
					}
				}
		}
	}
}