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
	imgui.text(state.current_path);
	was_allocation = false;
	out_file = "";
	if imgui.button("Parent")
	{
		folder := path.dir(state.current_path);
		log.info(folder);
		out_file = folder;
		return;
	}
	for file in files
	{
		if (path.ext(file.name) == ".png" || path.ext(file.name) == "") && imgui.button(file.name)
		{
			file_name := strings.clone(file.name);
			was_allocation = true;
			out_file = strings.concatenate([]string{state.current_path, "/", file_name}, allocator);
		}
	}
	return;
}