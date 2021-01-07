package editor

import win32 "core:sys/windows"
import "core:os"
import "core:log"
import path "core:path/filepath"
import "../imgui";
import "core:strings"

init_folder_display :: proc(path: string, state: ^Folder_Display_State) -> os.Errno
{
	handle, errno1 := os.open(path);
	state.current_path = path;

	files, errno2 := os.read_dir(handle, 100, context.allocator);
	os.close(handle);
	state.files = files;

	return errno1;
}

update_folder_display :: proc(state: ^Folder_Display_State) -> os.Errno
{
	delete(state.files);
	handle, errno1 := os.open(state.current_path);

	files, errno2 := os.read_dir(handle, 100, context.allocator);
	state.files = files;
	os.close(handle);

	return errno1;
}

folder_display :: proc(using state: ^Folder_Display_State, allocator := context.allocator) -> (out_file: string, was_allocation: bool)
{
	if imgui.button("Select Folder")
	{
		imgui.open_popup("Select Folder");
	}
	if imgui.begin_popup_modal("Select Folder", nil, .AlwaysAutoResize)
	{
		imgui.text(state.current_path);
		was_allocation = false;
		out_file = "";
		if imgui.button("Parent")
		{
			folder := path.dir(state.current_path);
			log.info(folder);
			out_file = folder;
		}
		else
		{
			for file in files
			{
				if (path.ext(file.name) == ".png" || path.ext(file.name) == "") && imgui.button(file.name)
				{
					file_name := strings.clone(file.name);
					was_allocation = true;
					out_file = strings.concatenate([]string{state.current_path, "/", file_name}, allocator);
				}
			}

		}
		imgui.end_popup();
	}
	return;
}

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
		if path.ext(current_path) == ".png"
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