package serialization

import "core:os"
import "core:reflect"
import "core:runtime"
import "core:mem"
import "core:fmt"
import "core:strings"
import "core:encoding/json"
import "core:log"

Json_Write_State :: struct
{
	tab_count: int,
	has_precedent: bool,
}

json_write_struct :: proc(file: os.Handle, data: rawptr, type_info: ^runtime.Type_Info, write_state: ^Json_Write_State, braces := false)
{
	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			if braces do json_write_open_body(file, write_state);
			struct_info, ok := type_info.variant.(runtime.Type_Info_Struct);
			for name, index in struct_info.names
			{
				json_write_member(file, name, write_state);
				json_write_struct(file, rawptr(uintptr(data) + struct_info.offsets[index]), struct_info.types[index], write_state, true);
			}
			if braces do json_write_close_body(file, write_state);

		case runtime.Type_Info_Named:
			json_write_struct(file, data, variant.base, write_state, braces);
		case runtime.Type_Info_Float:
			os.write_string(file, fmt.tprint((cast(^f32)(data))^));
			write_state.has_precedent = true;
		case runtime.Type_Info_Integer:
			os.write_string(file, fmt.tprint(any{data, type_info.id}));
			write_state.has_precedent = true;
		case runtime.Type_Info_String:
			json_write_value(file, (cast(^string)data)^, write_state);
			write_state.has_precedent = true;
		case runtime.Type_Info_Array:
			os.write_byte(file, '[');
			write_state.tab_count += 1;
			for i in 0..<variant.count
			{
				if i > 0 do os.write_string(file, ", ");
				element_size := variant.elem_size;
				json_write_struct(file, rawptr(uintptr(data) + uintptr(i * variant.elem_size)), variant.elem, write_state);
			}
			os.write_byte(file, ']');
			write_state.has_precedent = true;
			write_state.tab_count -= 1;
	}
}

// same as reflect.struct_field_by_name, but goes inside params with using
find_struct_field :: proc(type_info: ^runtime.Type_Info, name: string) -> (field: reflect.Struct_Field, field_found: bool)
{
	field_found = false;
	ti := runtime.type_info_base(type_info);
	if s, ok := ti.variant.(runtime.Type_Info_Struct); ok {
		for fname, i in s.names {
			if fname == name {
				field.name   = s.names[i];
				field.type   = s.types[i];
				field.tag    = reflect.Struct_Tag(s.tags[i]);
				field.offset = s.offsets[i];
				field_found = true;
				return;
			}
			else if s.usings[i] {
				if child_field, ok := find_struct_field(s.types[i], name); ok {
					field = child_field;
					field.offset += s.offsets[i];
					field_found = true;
					return;
				}
			}
		}
	}
	return;
}

parse_json_float :: proc(json_data: json.Value) -> f32
{
	#partial switch v in json_data
	{
		case json.Integer:
			return f32(v);
		case json.Float:
			return f32(v);
	}
	return 0;
}

json_read_struct :: proc(json_data: json.Object, ti: ^runtime.Type_Info, allocator := context.allocator) -> rawptr
{
	base_ti := runtime.type_info_base(ti);
	result := mem.alloc(ti.size, ti.align, allocator);
	
	for name, value in json_data
	{
		field, field_found := find_struct_field(base_ti, name);
		#partial switch t in value
		{
			case json.Object:
			{
				//log.info("OBJECT");
			}
			case json.Array:
			{
				if(field.type.size == size_of(f32) * len(t))
				{
					for i := 0; i < len(t); i += 1
					{
						x := parse_json_float(t[i]);
						{
							fieldPtr := uintptr(result) + field.offset;
							mem.copy(rawptr(fieldPtr + uintptr(size_of(f32) * i)), &x, size_of(f32));
						}
					}

				}
			}
			case json.Integer:
			case json.Float:
			{
				// TODO : maybe handle f64 ?
				if field.type.id == typeid_of(f32)
				{
					field_ptr := cast(^f32)(uintptr(result) + field.offset);
					field_ptr^ = f32(t);
				}
			}
			case json.String:
			{
				if field.type.id == typeid_of(string)
				{
					str_copy := strings.clone(t, allocator);
					field_ptr := cast(^string)(uintptr(result) + field.offset);
					field_ptr^ = str_copy; 
				}
			}
		}
	}
	return result;
}

@(deferred_in=json_write_body_end)
json_write_body :: proc(file: os.Handle, using write_state: ^Json_Write_State, open_char := "{", close_char := "}")
{
    json_write_open_body(file, write_state, open_char);
}

json_write_body_end :: proc(file: os.Handle, using write_state: ^Json_Write_State, open_char := "{", close_char := "}")
{
	os.write_string(file, "\n");
	has_precedent = true;
	tab_count -= 1;
	json_write_tabs(file, write_state);
	os.write_string(file, close_char);
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

json_write_value :: #force_inline proc(file: os.Handle, name: string, using write_state: ^Json_Write_State)
{
	os.write_byte(file, '\"');
	output_value, was_allocation := strings.replace_all(name, "\\", "/", context.temp_allocator);
	os.write_string(file, output_value);
	os.write_byte(file, '\"');
	has_precedent = true;
}

json_write_scalar :: #force_inline proc(file: os.Handle, value: $T, using write_state: ^Json_Write_State)
{
	os.write_string(file, fmt.tprint(value));
	has_precedent = true;
}

typeid_to_string :: #force_inline proc(type_id: typeid, allocator := context.temp_allocator) -> string
{
	builder: strings.Builder = strings.make_builder_len_cap(0, 100, allocator);
	reflect.write_typeid(&builder, type_id);
	return strings.to_string(builder);
}

json_write_input :: #force_inline proc(file: os.Handle, input_index: int, using write_state: ^Json_Write_State)
{
	os.write_string(file, "\"&");
	os.write_string(file, fmt.tprint(input_index));
	os.write_byte(file, '\"');
	has_precedent = true;
}

json_write_ref :: #force_inline proc(file: os.Handle, name: string, using write_state: ^Json_Write_State)
{
	os.write_string(file, "\"@");
	os.write_string(file, name);
	os.write_byte(file, '\"');
	has_precedent = true;
}

json_write_tabs :: #force_inline proc(handle: os.Handle, using write_state: ^Json_Write_State)
{
	for i in 0..<tab_count do os.write_byte(handle, '\t');
}