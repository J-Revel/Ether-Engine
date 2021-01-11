package editor

import win32 "core:sys/windows"
import "core:os"
import "core:log"
import path "core:path/filepath"
import "../imgui";
import "core:strings"

file_selectors: map[string]File_Selection_Data;

is_file_selector_open :: proc(selector_id: string) -> bool
{
	return selector_id in file_selectors;
}

update_display_data :: proc(using state: ^File_Selection_Data)
{
	handle, errno1 := os.open(current_path);
	state.current_path = current_path;

	files, errno2 := os.read_dir(handle, 100, context.allocator);
	os.close(handle);
	display_data = files;
}

open_file_selector :: proc(selector_id: string, starting_folder: string)
{
	file_selector_data := File_Selection_Data{strings.clone(starting_folder), {}};
	update_display_data(&file_selector_data);
	file_selectors[selector_id] = file_selector_data;
}

file_selector_popup :: proc(selector_id: string, button_text: string, search_config: File_Search_Config) -> (out_path: string, search_state : File_Search_State)
{
	if imgui.button(button_text)
	{
		imgui.open_popup(selector_id);
		open_file_selector(selector_id, search_config.start_folder);
	}
	center := [2]f32{imgui.get_io().display_size.x * 0.5, imgui.get_io().display_size.y * 0.5};
	imgui.set_next_window_pos(center, .Appearing, [2]f32{0.5, 0.5});
	imgui.set_next_window_size({500, 500});
	if imgui.begin_popup_modal(selector_id, nil, .AlwaysAutoResize)
	{
		out_path, search_state = file_selector(selector_id, search_config);
		if search_state == .Found do imgui.close_current_popup();
		if imgui.button("Close")
		{
			search_state = .Stopped;
			imgui.close_current_popup();
		}
		imgui.end_popup();
	}

	return;
}

is_file_visible :: proc (file: os.File_Info, using search_config: File_Search_Config) -> bool
{
	file_ext := path.ext(file.name);
	if len(file_ext) == 0 do return !hide_folders;
	switch search_config.filter_type
	{
		case .All:
			return true;
		case .Show_With_Ext:
			for ext in extensions
			{
				if ext == file_ext do return true;
			}
			return false;
		case .Hide_With_Ext:
			for ext in extensions
			{
				if ext == file_ext do return false;
			}
			return true;
	}
	return false;
}

has_extension :: proc (path: string, using search_config: File_Search_Config) -> bool
{
	switch search_config.filter_type
	{
		case .All:
			return true;
		case .Show_With_Ext:
			for ext in extensions
			{
				if strings.has_suffix(path, ext) do return true;
			}
			return false;
		case .Hide_With_Ext:
			for ext in extensions
			{
				if strings.has_suffix(path, ext) do return false;
			}
			return true;
	}
	return false;
}

filter_files :: proc(files: []os.File_Info, search_config: File_Search_Config, allocator := context.temp_allocator) -> []os.File_Info
{
	r := make([dynamic]os.File_Info, 0, 0, allocator);
	for file in files {
		if is_file_visible(file, search_config) {
			append(&r, file);
		}
	}
	return r[:];
}

file_selector :: proc(selector_id: string, search_config: File_Search_Config) -> (out_path: string, search_state: File_Search_State)
{
	assert(selector_id in file_selectors);
	using file_selector_data: ^File_Selection_Data = &file_selectors[selector_id];

	search_state = .Searching;

	imgui.text(current_path);

	path_change := false;
	new_path: string;
	new_file: os.File_Info;
	
	if current_path != ""
	{
		if imgui.button("..")
		{
			path_change = true;
			new_path = strings.clone(path.dir(current_path), context.allocator);
			log.info(new_path);
		}
	}

	for file in filter_files(display_data, search_config)
	{
		if imgui.button(file.name)
		{
			path_change = true;
			new_file = file;
			new_path = strings.concatenate([]string{current_path, "/", file.name}, context.allocator);
			break;
		}
	}

	if path_change
	{
		delete(display_data);
		delete(current_path);
		log.info(new_path);
		current_path = new_path;
		if has_extension(current_path, search_config)
		{
			search_state = .Found;
			delete_key(&file_selectors, selector_id);
		}
		out_path = new_path;
		update_display_data(file_selector_data);
	}
	else
	{
		out_path = current_path;
	}
	return;
}