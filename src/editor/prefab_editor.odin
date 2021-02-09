package editor

import imgui "../imgui";
import "core:log"
import "core:strings"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:reflect"
import "core:slice"
import "core:os"
import "core:encoding/json"
import sdl "shared:odin-sdl2"

import "../geometry"
import "../gameplay"
import "../render"
import "../container"
import "../objects"
import "../animation"

init_prefab_editor :: proc(using editor_state: ^Prefab_Editor_State)
{
	gameplay.init_empty_scene(&scene);
	for type in objects.default_input_types
	{
		append(&input_types, type);
	}
	for component_type_id in &scene.db.component_types
	{
		editor_type_callbacks[component_type_id.value] = handle_editor_callback;
		append(&input_types, objects.Prefab_Input_Type{component_type_id.name, component_type_id.value});
	}

	editor_type_callbacks[typeid_of([]animation.Animation_Param)] = animation_player_editor_callback;
}

get_component_field_data :: proc(components: []objects.Component_Model, using field: Component_Model_Field) -> uintptr
{
	return (uintptr(components[field.component_index].data.data) + field.offset_in_component);
}

get_component_input_index :: proc(components: []objects.Component_Model, field: Component_Model_Field) -> int
{
	using components[field.component_index].data;
	for input_index in 0..input_count
	{
		input := inputs[input_index];
		if input.field.type == field.type_id && input.field.offset == field.offset_in_component
		{
			return input_index;
		}
	}
	return -1;
}

get_component_ref_index :: proc(components: []objects.Component_Model, field: Component_Model_Field) -> (int, int)
{
	using components[field.component_index].data;
	for ref, index in refs[0:ref_count]
	{
		if ref.field.offset == field.offset_in_component
		{
			return index, ref.component_index;
		}
	}
	return -1, -1;
}

set_field_ref :: proc(components: []objects.Component_Model, field: Component_Model_Field, new_ref: objects.Component_Ref) -> bool
{
	modified := false;
	input_index := get_component_input_index(components[:], field);
	ref_index, ref_target := get_component_ref_index(components[:], field);
	using components[field.component_index].data;
	if input_index >= 0
	{
		slice.swap(inputs[0:ref_count], input_index, ref_count - 1);
		ref_count -= 1;
	}

	if ref_index >= 0
	{
		if new_ref != refs[ref_index] do modified = true;
		refs[ref_index] = new_ref;
	}
	else
	{
		refs[ref_count] = new_ref;
		ref_count += 1;
	}
	return modified;
}

remove_field_ref :: proc(components: []objects.Component_Model, field: Component_Model_Field, ref_index: int)
{
	using components[field.component_index].data;
	refs[ref_index] = refs[ref_count - 1];
	ref_count -= 1;
}

set_field_input :: proc(components: []objects.Component_Model, field: Component_Model_Field, new_input: objects.Component_Input)
{
	input_index := get_component_input_index(components, field);
	ref_index, ref_target := get_component_ref_index(components, field);
	using components[field.component_index].data;
	// Remove selected ref
	if ref_index >= 0
	{
		old_refs := refs;
		slice.swap(refs[0:input_count], ref_index, ref_count - 1);
		ref_count -= 1;
	}

	if input_index >= 0
	{
		inputs[input_index] = new_input;
	}
	else
	{
		inputs[input_count] = new_input;
		input_count += 1;
	}
}

remove_field_input :: proc(components: []objects.Component_Model, field: Component_Model_Field, input_index: int)
{
	using components[field.component_index].data;
	inputs[input_index] = inputs[ref_count - 1];
	input_count -= 1;
}

remove_field_input_ref :: proc(components: []objects.Component_Model, field: Component_Model_Field)
{
	input_index := get_component_input_index(components, field);
	ref_index, ref_target := get_component_ref_index(components, field);
	
	using components[field.component_index].data;
	// Remove selected ref
	if ref_index >= 0
	{
		slice.swap(refs[:], ref_index, ref_count - 1);
		ref_count -= 1;
	}

	if input_index >= 0
	{
		slice.swap(inputs[:], input_index, ref_count - 1);
		ref_count -= 1;
	}
}

slice_remove_at :: proc(array: []$T, to_remove: []int) -> (new_len: int)
{
	log.info("Remove Refs", to_remove);
	if len(array) == 0 do return;
	n := len(array) - 1;
	slice.sort(to_remove[:]);
	for i := len(to_remove) - 1; i >= 0; i -= 1
	{
		slice.swap(array, to_remove[i], n);
		n -= 1;
	}
	return n + 1;
}

remove_component :: proc(using editor_state: ^Prefab_Editor_State, to_remove_index: int)
{
	record_history_step(editor_state);
	log.info("Remove component", to_remove_index);
	for component in &components
	{
		refs_to_remove: [dynamic]int;
		using component.data;
		for ref_index in 0..<ref_count
		{
			if refs[ref_index].component_index == to_remove_index
			{
				append(&refs_to_remove, ref_index);
			}
			else if refs[ref_index].component_index > to_remove_index
			{
				refs[ref_index].component_index -= 1;
			}
		}

		ref_count = slice_remove_at(component.data.refs[0:ref_count], refs_to_remove[:]);
	}
	ordered_remove(&components, to_remove_index);
}

input_ref_combo :: proc(id: string, field: Component_Model_Field, using editor_state: ^Prefab_Editor_State) -> bool
{
	modified := false;
	selected_ref_index, selected_ref_target := get_component_ref_index(components[:], field);
	
	selected_input_index := get_component_input_index(components[:], field);
	current_value_name := "nil";
	selected_input_name : string;
	if selected_input_index >= 0 
	{
		input_index := components[field.component_index].data.inputs[selected_input_index].input_index;
		
		if input_index < 0
		{
			selected_input_name = "nil";
			current_value_name = "nil";
		}
		else
		{
			selected_input_name = inputs[input_index].name;
			current_value_name = fmt.tprintf("(input)%s", selected_input_name);
		}
	}
	else if selected_ref_index >= 0
	{
		current_value_name = fmt.tprintf("(ref)%s", components[selected_ref_target].id);
	}

	display_value := current_value_name;

	struct_field := reflect.Struct_Field
	{
		name = field.name, 
		type = field.type_id, 
		offset = field.offset_in_component
	};
	if imgui.begin_combo(id, display_value, .PopupAlignLeft)
	{
		reference_found, input_found: bool;
		ref_input_index: int;

		for component, index in components
		{
			if scene.db.tables[component.table_index].table.handle_type_id == field.type_id 
			{
				ref_input_index = index;
				if !reference_found do imgui.text_unformatted("References :");
				reference_found = true;
				if imgui.selectable(component.id, selected_ref_target == index)
				{
					new_ref := objects.Component_Ref{index, struct_field};

					set_field_ref(components[:], field, new_ref);
					modified = true;
				}
			}
		}
		imgui.separator();

		for input, index in inputs
		{
			ref_input_index = index;
			if input.type_id == field.type_id
			{
				if !input_found do imgui.text_unformatted("Inputs :");
				input_found = true;
				if imgui.selectable(input.name, selected_input_name == input.name)
				{
					new_input := objects.Component_Input{index, struct_field};
					set_field_input(components[:], field, new_input);
					modified = true;
				}
			}
		}

		imgui.separator();

		if imgui.selectable("nil", !reference_found && !input_found)
		{
			if reference_found
			{
				remove_field_ref(components[:], field, ref_input_index);
			}
			else if input_found
			{
				remove_field_input(components[:], field, ref_input_index);

			}
		}
		imgui.end_combo();
	}
	return modified;
}

sprite_handle_editor_callback :: proc(db: ^container.Database, element: any)
{
	assert(element.id == typeid_of(container.Handle(render.Sprite)));
	imgui.button("SPRITE_HANDLE");
}

transform_handle_editor_callback :: proc(db: ^container.Database, element: any)
{
	assert(element.id == typeid_of(container.Handle(gameplay.Transform)));
	imgui.button("TRANSFORM_HANDLE");
}

component_editor :: proc
{
	component_editor_root,
	component_editor_child
};

component_editor_root :: proc(using editor_state: ^Prefab_Editor_State, component: ^objects.Component_Model, component_index: int)
{
	component_table := scene.db.tables[component.table_index];
	component_type_id := runtime.typeid_base(component_table.table.type_id);
	if component.data.data == nil
	{
		component_type := type_info_of(component_type_id);
		component.data.data = mem.alloc(component_type.size, component_type.align);
	}
	component_data := any{component.data.data, component_type_id};
	if imgui.begin_menu_bar()
	{
		imgui.columns(2);
		imgui.input_string("Name", &component.id);
		imgui.next_column();
		if imgui.begin_combo("Type", component_table.name, .PopupAlignLeft)
		{
			for named_table, index in scene.db.tables
			{
				if imgui.selectable(named_table.name, index == component.table_index)
				{
					component.table_index = index;
					mem.free(component.data.data);
					type_info := type_info_of(named_table.table.type_id);
					component.data.data = mem.alloc(type_info.size, type_info.align);
				}
			}
			imgui.end_combo();
		}
		imgui.next_column();
		imgui.end_menu_bar();
	}
	imgui.columns(1);
	callback, callback_found := editor_type_callbacks[component_type_id];

	field_cursor := Component_Model_Field{component.id, component_index, 0, component_type_id};

	if callback_found
	{
		callback(editor_state, field_cursor);
		return;
	}

	type_info := type_info_of(component_data.id);
	for
	{
		#partial switch variant in type_info.variant
		{
			case runtime.Type_Info_Struct:
			structInfo, ok := type_info.variant.(runtime.Type_Info_Struct);
			imgui.columns(2);
			imgui.set_column_width(0, 150);
			for _, i in structInfo.names
			{
				
				//field := rawptr(uintptr(component_data.data) + structInfo.offsets[i]);
				field_cursor.offset_in_component = structInfo.offsets[i];
				child_field := Component_Model_Field{structInfo.names[i], component_index, structInfo.offsets[i], structInfo.types[i].id};
				component_editor_child(editor_state, structInfo.names[i], child_field);
			}
			return;

			case runtime.Type_Info_Named:
				type_info = type_info_of(variant.base.id);
		}
	}
}

component_editor_child :: proc(using editor_state: ^Prefab_Editor_State, base_name: string, field: Component_Model_Field)
{
	type_info := type_info_of(field.type_id);
	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
		case runtime.Type_Info_Named:
		case:
			imgui.text_unformatted(base_name);
			imgui.next_column();
	}
	imgui.push_id(base_name);
	callback, callback_found := editor_type_callbacks[field.type_id];
	if callback_found
	{
		imgui.text_unformatted(base_name);
		imgui.next_column();
		callback(editor_state, field);
		imgui.pop_id();
		imgui.next_column();
		return;
	}
	text_buffer := make([]u8, 200, context.temp_allocator);

	input_index := get_component_input_index(components[:], field);
	ref_index, ref_target := get_component_ref_index(components[:], field);
	
	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			if imgui.tree_node(base_name)
			{
				imgui.next_column();
				imgui.next_column();
				A, B: [2]f32;
				imgui.get_cursor_screen_pos(&A);
				offset_cursor: uintptr = 0;
				for _, i in variant.names
				{
					width := imgui.calc_item_width();
					imgui.push_id(variant.names[i]);
					child_type := variant.types[i];
					child_field: Component_Model_Field = {variant.names[i], field.component_index, field.offset_in_component + variant.offsets[i], child_type.id};
					component_editor_child(editor_state, variant.names[i], child_field);
					imgui.pop_id();
				}
				imgui.get_cursor_screen_pos(&B);
				imgui.tree_pop();
			}
		case runtime.Type_Info_Named:
			child_field := field;
			child_field.type_id = variant.base.id;
			component_editor_child(editor_state, base_name, child_field);
		case runtime.Type_Info_Integer:
			if input_index >= 0
			{
				if input_ref_combo("", field, editor_state) do record_history_step(editor_state);
				imgui.same_line();
				if imgui.button("remove input")
				{
					remove_field_input_ref(components[:], field);
				}
			}
			else
			{
				imgui.push_item_width(imgui.get_window_width() * 0.5);
				if imgui.input_int("", cast(^i32) get_component_field_data(components[:], field))
				{
					record_history_step(editor_state);
				}
				imgui.same_line();
				if imgui.button("input")
				{
					struct_field := reflect.Struct_Field
					{
						name = field.name, 
						type = field.type_id, 
						offset = field.offset_in_component
					};
					new_input := objects.Component_Input{-1, struct_field};
					set_field_input(components[:], field, new_input);
					record_history_step(editor_state);
				}
				imgui.pop_item_width();
			}
		case runtime.Type_Info_Float:
			imgui.push_item_width(imgui.get_window_width() * 0.5);
			if imgui.input_float("", cast(^f32) get_component_field_data(components[:], field))
			{
				record_history_step(editor_state);
			}
			imgui.same_line();
			if imgui.button("input")
			{
				struct_field := reflect.Struct_Field
				{
					name = field.name, 
					type = field.type_id, 
					offset = field.offset_in_component
				};
				new_input := objects.Component_Input{-1, struct_field};
				set_field_input(components[:], field, new_input);
				record_history_step(editor_state);
			}
			imgui.pop_item_width();
		case runtime.Type_Info_String:
			str := cast(^string)get_component_field_data(components[:], field);
			if imgui.input_string("", str, 200)
			{
				record_history_step(editor_state);
				str^ = strings.clone(str^, context.allocator);
			}
		case runtime.Type_Info_Array:
			data_type: imgui.Data_Type = .Count;
			format := "%d";
			switch(variant.elem.id)
			{
				case typeid_of(i32):
					data_type = .S32;
				case typeid_of(u32):
					data_type = .U32;
				case typeid_of(i64):
					data_type = .S64;
				case typeid_of(u64):
					data_type = .U64;
				case typeid_of(int):
					data_type = (size_of(typeid_of(int)) == 8) ? .S64:.S32;
				case typeid_of(f32):
					data_type = .Float;
					format = "%.3f";
				case typeid_of(f64):
					data_type = .Double;
					format = "%.6f";
			}
			if imgui.input_scalar_n("", data_type, rawptr(get_component_field_data(components[:], field)), i32(variant.count), nil, nil, format)
			{
				record_history_step(editor_state);
			}

			if data_type == .Count
			{
				for i in 0..<variant.count
				{
					imgui.push_id(fmt.tprintf("element_%d", i));
					char := 'x' + i;
					txt := fmt.tprintf("%c", char);
					component_editor_child(editor_state, txt, {"", field.component_index, field.offset_in_component + uintptr(variant.elem_size * i), variant.elem.id});
					imgui.pop_id();
				}
			}
	}
	imgui.pop_id();
	imgui.next_column();
}

update_prefab_editor :: proc(using editor_state: ^Prefab_Editor_State)
{
	io := imgui.get_io();
	
	extensions := []string{".prefab"};
	search_config := File_Search_Config{
			start_folder = "config/prefabs", 
			filter_type = .Show_With_Ext, 
			extensions = extensions, 
			hide_folders = false, 
			can_create = false, 
			confirm_dialog = false
		};
	path, file_search_state := file_selector_popup("prefab_load", "Load Prefab", search_config);
	
	if file_search_state == .Found
	{
		loaded_prefab, success := objects.load_prefab(path, &scene.db, context.allocator);
		clear(&components);
		for component in loaded_prefab.components
		{
			append(&components, component);
		}
		clear(&inputs);
		for input in loaded_prefab.inputs
		{
			append(&inputs, input);
		}
		//delete(loaded_prefab.components);
	}

	if io.key_ctrl && io.keys_down[sdl.Scancode.W] && !z_down
	{
		undo_history(editor_state);
	}
	z_down = io.keys_down[sdl.Scancode.W];
	if(imgui.begin_child("Inputs", [2]f32{0, 55 + 23 * f32(len(inputs))}, true, .MenuBar))
	{
		if imgui.begin_menu_bar()
		{
			imgui.text("Inputs");
			imgui.end_menu_bar();
		}
		imgui.columns(2);
		imgui.set_column_width(0, 150);
		for input, index in &inputs
		{
			imgui.push_id(fmt.tprintf("input_%d", index));
			imgui.input_string("name", &input.name);
			imgui.next_column();

			selected_input_type := 0;
			for input_type, index in input_types
			{
				if input_type.type_id == input.type_id
				{
					selected_input_type = index;
				}
			}
			if imgui.begin_combo("type", input_types[selected_input_type].name, .PopupAlignLeft)
			{
				for input_type, index in input_types
				{
					if imgui.selectable(input_type.name, input_type.type_id == input.type_id)
					{
						input.type_id = input_type.type_id;
					}
				}
				imgui.end_combo();
			}
			imgui.pop_id();
			imgui.next_column();
		}
		imgui.columns(1);
		if imgui.button("Add Input") do append(&inputs, objects.Prefab_Input{});
		imgui.end_child();
	}
	to_remove: int;
	for component, index in &components
	{
		imgui.push_id(fmt.tprintf("Component_%d", index));
		flags : imgui.Tree_Node_Flags = .SpanFullWidth | .DefaultOpen;
		table_name := scene.db.tables[component.table_index].name;
		if(imgui.begin_child("component", [2]f32{0, 250}, true, .MenuBar))
		{
			component_editor(editor_state, &component, index);
			imgui.columns(1);
			if imgui.button("Remove Component")
			{
				to_remove = index + 1;
				record_history_step(editor_state);
			}
			imgui.end_child();
		}
		imgui.pop_id();
	}
	if to_remove > 0
	{
		remove_component(editor_state, to_remove - 1);
	}
	if(imgui.button("+"))
	{
		component := objects.Component_Model{};
		append(&components, component);
		record_history_step(editor_state);
	}
	// if(imgui.button("Save"))
	// {

		search_config = File_Search_Config{
			start_folder = "config/prefabs", 
			filter_type = .Show_With_Ext, 
			extensions = extensions, 
			hide_folders = false, 
			can_create = true, 
			confirm_dialog = true,
		};
		path, file_search_state = file_selector_popup("prefab_save", "Save Prefab", search_config);

		if file_search_state == .Found
		{
			save_prefab(editor_state, path);
		}
	// }
}

json_write_open_body :: proc(file: os.Handle, using write_state: ^Json_Write_State, character := "{")
{
	if has_precedent
	{
		os.write_string(file, ",\n");
		json_write_tabs(file, write_state);
	}
	os.write_string(file, character);
	has_precedent = false;

	tab_count += 1;
}

json_write_close_body ::  proc(file: os.Handle, using write_state: ^Json_Write_State, character := "}")
{
	os.write_string(file, "\n");
	has_precedent = true;
	tab_count -= 1;
	json_write_tabs(file, write_state);
	os.write_string(file, character);
}

json_write_member :: proc(file: os.Handle, name: string, using write_state: ^Json_Write_State)
{
	if has_precedent do os.write_byte(file, ',');
	os.write_byte(file, '\n');
	json_write_tabs(file, write_state);
	os.write_byte(file, '\"');
	os.write_string(file, name);
	os.write_byte(file, '\"');
	os.write_byte(file, ':');
	has_precedent = false;
}

json_write_value :: inline proc(file: os.Handle, name: string, using write_state: ^Json_Write_State)
{
	os.write_byte(file, '\"');
	os.write_string(file, name);
	os.write_byte(file, '\"');
	has_precedent = true;
}

typeid_to_string :: inline proc(type_id: typeid, allocator := context.temp_allocator) -> string
{
	builder: strings.Builder = strings.make_builder_len_cap(0, 100, allocator);
	reflect.write_typeid(&builder, type_id);
	return strings.to_string(builder);
}

json_write_input :: inline proc(file: os.Handle, input_index: int, using write_state: ^Json_Write_State)
{
	os.write_string(file, "\"&");
	os.write_string(file, fmt.tprint(input_index));
	os.write_byte(file, '\"');
	has_precedent = true;
}

json_write_ref :: inline proc(file: os.Handle, name: string, using write_state: ^Json_Write_State)
{
	os.write_string(file, "\"@");
	os.write_string(file, name);
	os.write_byte(file, '\"');
	has_precedent = true;
}

json_write_tabs :: inline proc(handle: os.Handle, using write_state: ^Json_Write_State)
{
	for i in 0..<tab_count do os.write_byte(handle, '\t');
}

Json_Write_State :: struct
{
	tab_count: int,
	has_precedent: bool,
}

json_write_component_member :: proc(file: os.Handle, using editor_state: ^Prefab_Editor_State, component: objects.Component_Model_Data, type_info: ^runtime.Type_Info, offset: uintptr, write_state: ^Json_Write_State)
{
	for input_index in 0..<component.input_count
	{
		input := component.inputs[input_index];
		if input.field.offset == offset
		{
			json_write_input(file, input.input_index, write_state);
			return;
		}
	}
	for ref_index in 0..<component.ref_count
	{
		ref := component.refs[ref_index];
		if ref.field.offset == offset
		{
			json_write_ref(file, components[ref.component_index].id, write_state);
			return;
		}
	}

	for component_type in scene.db.component_types
	{
		if component_type.value == type_info.id
		{
			json_write_value(file, "nil", write_state);
			return;
		}
	} 

	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			json_write_open_body(file, write_state);
			struct_info, ok := type_info.variant.(runtime.Type_Info_Struct);
			for name, index in struct_info.names
			{
				json_write_member(file, name, write_state);
				json_write_component_member(file, editor_state, component, struct_info.types[index], offset + struct_info.offsets[index], write_state);
			}
			json_write_close_body(file, write_state);

		case runtime.Type_Info_Named:
			json_write_component_member(file, editor_state, component, type_info_of(variant.base.id), offset, write_state);
		case runtime.Type_Info_Float:
			os.write_string(file, fmt.tprint((cast(^f32)(uintptr(component.data) + offset))^));
			write_state.has_precedent = true;
		case runtime.Type_Info_Integer:
			os.write_string(file, fmt.tprint(any{rawptr(uintptr(component.data) + offset), type_info.id}));
			write_state.has_precedent = true;
		case runtime.Type_Info_String:
			json_write_value(file, (cast(^string)(uintptr(component.data) + offset))^, write_state);
			write_state.has_precedent = true;
		case runtime.Type_Info_Array:
			os.write_byte(file, '[');
			write_state.tab_count += 1;
			for i in 0..<variant.count
			{
				if i > 0 do os.write_string(file, ", ");
				component_data := component.data;
				element_size := variant.elem_size;
				json_write_component_member(file, editor_state, component, variant.elem, offset + uintptr(i * variant.elem_size), write_state);
			}
			os.write_byte(file, ']');
			write_state.has_precedent = true;
			write_state.tab_count -= 1;
	}
}

save_prefab :: proc(using editor_state: ^Prefab_Editor_State, path: string)
{
	file, errno := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC);
	if errno == 0
	{
		write_state: Json_Write_State;
		json_write_open_body(file, &write_state);
		json_write_member(file, "inputs", &write_state);
			json_write_open_body(file, &write_state, "[");
			for input in inputs
			{
				json_write_open_body(file, &write_state);

				json_write_member(file, "name", &write_state);
				json_write_value(file, input.name, &write_state);
				json_write_member(file, "type", &write_state);

				input_types := objects.get_input_types_list(&scene.db);
				for input_type in input_types
				{
					// TODO : if type_id is nil, empty type
					if input_type.type_id == input.type_id do json_write_value(file, input_type.name, &write_state);
				}

				json_write_close_body(file, &write_state);
			}
			json_write_close_body(file, &write_state, "]");
			write_state.has_precedent = true;
		json_write_member(file, "components", &write_state);
			json_write_open_body(file, &write_state);
			for component in components
			{
				json_write_member(file, component.id, &write_state);
				json_write_open_body(file, &write_state);
				json_write_member(file, "type", &write_state);
				component_table := scene.db.tables[component.table_index];
				json_write_value(file, component_table.name, &write_state);
				component_type_id := runtime.typeid_base(component_table.table.type_id);
				type_info := type_info_of(component_type_id);

				for type_info != nil
				{
					#partial switch variant in type_info.variant
					{
						case runtime.Type_Info_Struct:
						struct_info, ok := type_info.variant.(runtime.Type_Info_Struct);
						for name, index in struct_info.names
						{
							json_write_member(file, name, &write_state);
							json_write_component_member(file, editor_state, component.data, struct_info.types[index], struct_info.offsets[index], &write_state);
						}
						type_info = nil;

						case runtime.Type_Info_Named:
							type_info = type_info_of(variant.base.id);
					}

				}

				json_write_close_body(file, &write_state);
				
			}
			json_write_close_body(file, &write_state);
		json_write_close_body(file, &write_state);
		os.close(file);
	}
	else
	{
		log.error("Error trying to save to file", path, ":", errno);
	} 
}

record_history_step :: proc(using editor_state: ^Prefab_Editor_State)
{
	components_copy := make([]objects.Component_Model, len(components));
	copy(components_copy, components[:]);
	for component, index in &components_copy
	{
		component_table := scene.db.tables[component.table_index];
		component_type_id := runtime.typeid_base(component_table.table.type_id);
		component_type := type_info_of(component_type_id);
		component.data.data = mem.alloc(component_type.size, component_type.align);
		mem.copy(component.data.data, components[index].data.data, component_type.size);
		component.id = strings.clone(components[index].id, context.allocator);
	}
	append(&components_history, components_copy);
}

undo_history :: proc(using editor_state: ^Prefab_Editor_State)
{
	if len(components_history) == 0 do return;
	backup_components := pop(&components_history);
	clear(&components);
	for component in backup_components
	{
		component_table := scene.db.tables[component.table_index];
		component_type_id := runtime.typeid_base(component_table.table.type_id);
		component_type := type_info_of(component_type_id);
		log.info(any{component.data.data, component_type_id});
		append(&components, component);
	}
	delete(backup_components);
}