package editor

import imgui "../../libs/imgui";
import "../render"
import "core:log"
import "core:strings"
import "../container"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:reflect"
import "core:os"
import "core:path"
import "../animation"
import "../gameplay"

import "../geometry"
import "../objects"

Sprite_Selection_Data :: struct
{
	using texture_selection_data: File_Selection_Data,
	selection_open: bool,
	texture: render.Texture_Handle,
	search_config: File_Search_Config,
	has_file_selected: bool,
	selected_file: string,
	selected_texture: render.Texture_Handle,
}

sprite_selectors: map[string]Sprite_Selection_Data;
available_sprite_extensions := [?]string{".meta"};

sprite_selector :: proc(scene: ^gameplay.Scene, selector_id: string, start_folder: string) -> (out_sprite: render.Sprite_Handle, search_state: File_Search_State)
{
	sprite_selector_popup_id := fmt.tprint(selector_id, "sprite");
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
			extensions = available_sprite_extensions[:],
		};
		found_path, search_state := file_selector_popup_button(selector_id, "Select Sprite", search_config);
		switch search_state
		{
			case .Found:

				// TODO : load corresponding texture if not already in db (=> path = found_path - ".meta")
				texture_path := fmt.tprintf("%s.png", found_path[0:len(found_path)-5]);
				texture_found: bool;
				selection_data.texture, texture_found = render.get_or_load_texture(&scene.sprite_database, texture_path);
				assert(texture_found);
				render.load_sprites_to_db(&scene.sprite_database, selection_data.texture, found_path);
				imgui.open_popup(sprite_selector_popup_id);
			case .Stopped:
				return {}, .Stopped;
			case .Searching:

		}
	}
	if imgui.begin_popup_modal(sprite_selector_popup_id)
	{
		sprite_it := container.table_iterator(&scene.sprites);
		for sprite, sprite_id in container.table_iterate(&sprite_it)
		{
			if sprite.texture == selection_data.texture
			{
				imgui.push_id(sprite.id);
				if sprite_widget(scene, sprite_id)
				{
					imgui.close_current_popup();
					delete_key(&sprite_selectors, selector_id);
					imgui.pop_id();
					imgui.end_popup();
					return sprite_id, .Found;
				}
				imgui.same_line();
				imgui.pop_id();
			}
		}
		if imgui.button("Back", {100, 100})
		{
			imgui.close_current_popup();
			delete_key(&sprite_selectors, selector_id);
			imgui.end_popup();
			return {}, .Stopped;
		}
		imgui.end_popup();
	}
	return {}, .Searching;
}

open_sprite_selector :: proc(selector_id: string, start_folder: string)
{
	search_config := File_Search_Config{
		start_folder = start_folder,
		filter_type = .Show_With_Ext,
		extensions = available_sprite_extensions[:],
	};
	if selector_id not_in sprite_selectors
	{
		sprite_selectors[selector_id] = {search_config = search_config};
	}
	open_file_selector(selector_id, start_folder);
}

remove_extension :: proc(file_path: string, allocator := context.allocator) -> (name: string) {
	name = file_path;

	for i := len(file_path)-1; i >= 0 && !path.is_separator(file_path[i]); i -= 1 {
		if file_path[i] == '.' {
			name = file_path[:i];
			return;
		}
	}
	return file_path;

}

sprite_selector_popup_content :: proc(using db: ^render.Sprite_Database, selector_id: string) -> (render.Sprite_Asset, File_Search_State)
{
	using sprite_selector_state := &sprite_selectors[selector_id];
	files := file_selector_list(selector_id, search_config);
	for file in files
	{
		if imgui.selectable(file.name, has_file_selected && selected_file == file.fullpath, .DontClosePopups)
		{
			selected_file = file.fullpath;
			has_file_selected = true;
			asset_path := selected_file[0:len(selected_file)-5];
			texture_path := fmt.tprintf("%s.png", asset_path);
			spritesheet_path := fmt.tprintf("%s.meta", asset_path);
			texture_handle, texture_found := render.get_or_load_texture(db, texture_path);
			assert(texture_found);
			render.load_sprites_to_db(db, texture_handle, spritesheet_path);
			selected_texture = texture_handle;
		}
	}
	if has_file_selected
	{
		sprite_it := container.table_iterator(&sprites);
		for sprite, sprite_id in container.table_iterate(&sprite_it)
		{
			if sprite.texture == selected_texture
			{
				imgui.push_id(sprite.id);
				if sprite_widget(db, sprite_id)
				{
					imgui.close_current_popup();
					delete_key(&sprite_selectors, selector_id);
					imgui.pop_id();
					texture_data := container.handle_get(selected_texture);

					return {remove_extension(texture_data.path), sprite.id}, .Found;
				}
				imgui.same_line();
				imgui.pop_id();
			}
		}
	}
	imgui.separator();
	imgui.button("nil", {100, 100});
	return {}, .Searching;
}