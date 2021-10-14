package imgui;

import "../input"
import "../render"
import "../util"
import "../container"
import "core:encoding/json"
import "core:strconv"
import "core:strings"
import "core:os"
import "core:reflect"
import "core:runtime"
import "core:log"

Theme_Error :: enum
{
	Unavailable_File,
}

Theme_Load_Error :: union
{
	json.Error,
	Theme_Error,
}

Theme_Save_Error :: union
{
	json.Marshal_Error,
	Theme_Error,
}

load_theme :: proc(path: string) -> (out_theme: UI_Theme, error: Theme_Load_Error)
{
	file, file_read := os.read_entire_file(path, context.temp_allocator);
	if !file_read do return out_theme, Theme_Error.Unavailable_File;
	parsed_json := json.parse(data = file, parse_integers = true) or_return;
	json_object := parsed_json.(json.Object);

	load_compound_theme(json_object, out_theme);
	return;
}

load_color :: proc(json_object: json.Object, name: string, out_color: ^Color) -> bool
{
	json_value, json_value_found := json_object[name];
	log.info("LOAD_COLOR", json_object, json_value_found);
	if !json_value_found do return false;
	value, is_integer := json_value.(json.Integer);
	if !is_integer do return false;
	out_color^ = Color(value);
	return true;
}

load_int :: proc(json_object: json.Object, name: string, out_value: ^int) -> bool
{
	json_value, json_value_found := json_object[name];
	if !json_value_found do return false;
	value, is_integer := json_value.(json.Integer);
	if !is_integer do return false;
	out_value^ = int(value);
	return true;
}

load_string :: proc(json_object: json.Object, name: string, out_value: ^string) -> bool
{
	json_value, json_value_found := json_object[name];
	if !json_value_found do return false;
	out_value^ = json_value.(json.String);
	return true;
}

load_corner_radius :: proc(json_object: json.Object, name: string, out_value: ^Corner_Radius) -> bool
{
	json_value, json_value_found := json_object[name];
	if !json_value_found do return false;
	int_value, is_integer := json_value.(json.Integer);
	float_value, is_float := json_value.(json.Float);
	if is_integer do out_value^ = int(int_value);
	else if is_float do out_value^ = f32(float_value);
	return is_integer || is_float;
}

load_rect_theme :: proc(json_root: json.Object, name: string, out_value: ^Rect_Theme) -> bool
{
	ok: bool;
	json_value, json_value_found := json_root[name];
	load_color(json_value.(json.Object), "fill_color", &out_value.fill_color);
	load_color(json_value.(json.Object), "border_color", &out_value.border_color);
	load_int(json_value.(json.Object), "border_thickness", &out_value.border_thickness);
	return true;
}

get_struct_type_info :: proc(type_info: ^runtime.Type_Info) -> runtime.Type_Info_Struct
{
	sub_type_info := type_info;
	struct_found: bool;
	result: runtime.Type_Info_Struct;
	for !struct_found
	{
		#partial switch type in sub_type_info.variant
		{
			case runtime.Type_Info_Struct:
				struct_found = true;
				return type;
			case runtime.Type_Info_Named:
				sub_type_info = type.base;
			case:
				log.info(type);
				return {};
		}
	}
	return {};
}

load_root_compound_theme :: proc(json_root: json.Object, out_value: any) -> bool
{
	type_info_struct := get_struct_type_info(type_info_of(out_value.id));
	for i in 0..<len(type_info_struct.names)
	{
		using type_info_struct;
		json_child := json_root;
		switch types[i].id
		{
			case typeid_of(string):
				load_string(json_child, names[i], cast(^string)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(int):
				load_int(json_child, names[i], cast(^int)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(Color):
				load_color(json_child, names[i], cast(^Color)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(Rect_Theme):
				load_rect_theme(json_child, names[i], cast(^Rect_Theme)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(Corner_Radius):
				load_corner_radius(json_child, names[i], cast(^Corner_Radius)(uintptr(out_value.data) + offsets[i]));
			case:
				load_compound_theme(json_child, names[i], any{id = types[i].id, data = rawptr(uintptr(out_value.data) + offsets[i])});
		}
	}
	return true;
}

load_sub_compound_theme :: proc(json_root: json.Object, name: string, out_value: any) -> bool
{
	json_child, ok := json_root[name].(json.Object);
	if !ok do return false;

	type_info_struct := get_struct_type_info(type_info_of(out_value.id));
	for i in 0..<len(type_info_struct.names)
	{
		using type_info_struct;
		switch types[i].id
		{
			case typeid_of(string):
				load_string(json_child, names[i], cast(^string)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(int):
				load_int(json_child, names[i], cast(^int)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(Color):
				load_color(json_child, names[i], cast(^Color)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(Rect_Theme):
				load_rect_theme(json_child, names[i], cast(^Rect_Theme)(uintptr(out_value.data) + offsets[i]));
			case typeid_of(Corner_Radius):
				load_corner_radius(json_child, names[i], cast(^Corner_Radius)(uintptr(out_value.data) + offsets[i]));
			case:
				load_compound_theme(json_child, names[i], any{id = types[i].id, data = rawptr(uintptr(out_value.data) + offsets[i])});
		}
	}
	return true;
}

load_compound_theme :: proc { load_root_compound_theme, load_sub_compound_theme };

save_theme :: proc(path: string, theme: UI_Theme) -> Theme_Save_Error
{
	json_str := json.marshal(theme, context.temp_allocator) or_return;
	if !os.write_entire_file(path, json_str) do return .Unavailable_File;
	return nil;
}

rect_theme_editor :: proc(using ctx: ^UI_Context, theme: ^Rect_Theme, ui_id: UI_ID = 0, location := #caller_location)
{
	ui_id := default_id(ui_id, location);
	color_picker_rgb(ctx, &theme.fill_color, 50, child_id(ui_id));
	color_picker_rgb(ctx, &theme.border_color, 50, child_id(ui_id));
	drag_int(ctx, &theme.border_thickness, child_id(ui_id));
	if theme.corner_radius == nil do theme.corner_radius = f32(0);
	switch value in theme.corner_radius
	{
		case int:
			number_editor(ctx, &theme.corner_radius.(int), 1, nil, child_id(ui_id));
		case f32:
			number_editor(ctx, &theme.corner_radius.(f32), 0.01, nil, child_id(ui_id));
	}
}

theme_editor :: proc(
	ctx: ^UI_Context, 
	theme: any, 
	editor_state: ^Theme_Editor_State,
	ui_id: UI_ID = 0, 
	location := #caller_location,
) -> bool
{
	ui_id := default_id(ui_id, location);
	type_info_struct := get_struct_type_info(type_info_of(theme.id));
	for i in 0..<len(type_info_struct.names)
	{
		using type_info_struct;
		id_child := child_id(id = ui_id, element_index = i);
		fold_state, ok := editor_state.fold_states[id_child];
		if !ok do fold_state = true;
		if fold(ctx, names[i], &fold_state, child_id(id_child))
		{
			data_ptr := uintptr(theme.data) + offsets[i];
			switch types[i].id
			{
				case typeid_of(string):
					value := cast(^string)data_ptr;
					label(ctx, value^);
				case typeid_of(int):
					value := cast(^int)data_ptr;
					number_editor(ctx, value, 1, nil, id_child);
				case typeid_of(Color):
					value := cast(^Color)data_ptr;
					color_picker_rgb(ctx, value, 50, id_child);
				case typeid_of(Corner_Radius):
					label(ctx, names[i]);
					
				case:
					theme_editor(ctx, any{id = types[i].id, data = rawptr(data_ptr)}, editor_state, id_child, location);
			}
			fold_end(ctx);
		}
		editor_state.fold_states[id_child] = fold_state;
	}
	return true;
}
