package prefab

import "core:log"
import "core:reflect"
import "core:mem"
import "core:os"
import "core:encoding/json"
import "core:runtime"
import "../container"
import "core:strconv"
import "core:strings"

default_input_types := [?]Prefab_Input_Type{
	{"int", typeid_of(int)}, 
	{"u32", typeid_of(u32)}, 
	{"i32", typeid_of(i32)}, 
	{"float", typeid_of(f32)}, 
	{"vec2", typeid_of([2]f32)},
};

get_input_types_list :: proc(db: ^container.Database, allocator := context.allocator) -> []Prefab_Input_Type
{
	result := make([dynamic]Prefab_Input_Type, allocator);
	
	for type in default_input_types
	{
		append(&result, type);
	}

	for component_type_id in &db.component_types
	{
		append(&result, Prefab_Input_Type{component_type_id.name, component_type_id.value});
	}
	return result[:];	
}

is_input_type :: proc(db: ^container.Database, type_id: typeid) -> bool
{
	for input_type in default_input_types
	{
		if type_id == input_type.type_id do return true;
	}
	for component_type in db.component_types
	{
		if component_type.value == type_id do return true;
	}
	return false;
}

get_input_types_map :: proc(db: ^container.Database, allocator := context.allocator) -> map[string]typeid
{
	result := make(map[string]typeid, 100, allocator);
	
	for type in default_input_types
	{
		result[type.name] = type.type_id;
	}

	for type in &db.component_types
	{
		result[type.name] = type.value;
	}
	return result;	
}

table_database_add_init :: proc(db: ^container.Database, name: string, table: ^container.Table($T), size: uint)
{
	container.table_init(table, size);
	named_table := container.Database_Named_Table{name, container.to_raw_table(table)};
	append(&db.tables, named_table);
	type_already_added := false;
	for type in db.component_types 
	{
		if type.value == typeid_of(container.Handle(T))
		{
			type_already_added = true;
		}
	}
	if !type_already_added do append(&db.component_types, container.Named_Element(typeid){name, typeid_of(container.Handle(T))});
	log.info("Create database", name);
}

prefab_instantiate_dynamic :: proc(db: ^container.Database, prefab: ^Dynamic_Prefab, input_data: map[string]any, metadata_dispatcher: ^Pending_Metadata_Dispatcher) -> (out_components: []Named_Raw_Handle, success: bool)
{
	return components_instantiate(db, prefab.components[:], prefab.inputs[:], input_data, metadata_dispatcher);
}

prefab_instantiate :: proc(db: ^container.Database, prefab: ^Prefab, input_data: map[string]any, metadata_dispatcher: ^Pending_Metadata_Dispatcher) -> (out_components: []Named_Raw_Handle, success: bool)
{
	return components_instantiate(db, prefab.components, prefab.inputs, input_data, metadata_dispatcher);
}

components_instantiate :: proc(db: ^container.Database, components: []Component_Model, inputs: []Prefab_Input, input_data: map[string]any, metadata_dispatcher: ^Pending_Metadata_Dispatcher) -> (out_components: []Named_Raw_Handle, success: bool)
{
	data_total_size := 0;
	components_data := make([]rawptr, len(components), context.temp_allocator);
	component_handles := make([]container.Raw_Handle, len(components), context.allocator); // TODO : can use temp allocator instead ?
	component_sizes := make([]int, len(components), context.temp_allocator);

	out_components = make([]Named_Raw_Handle, len(components), context.temp_allocator);

	for component, i in components
	{
		table := db.tables[component.table_index].table;
		component_sizes[i] = reflect.size_of_typeid(table.type_id);
		// TODO : check alignment
		components_data[i] = mem.alloc(component_sizes[i], align_of(uintptr), context.temp_allocator);

		log.info("START DATA", components_data[i]);
		log.info(any{components_data[i], table.type_id});
		mem.copy(components_data[i], component.data.data, component_sizes[i]);
		out_components[i].name = component.id;
	}

	for component, i in components
	{
		table := &db.tables[component.table_index].table;
		ok : bool;
		component_handles[i], ok = container.table_allocate_raw(table);
		out_components[i].value = component_handles[i];

	}
	for component, i in components
	{
		table := &db.tables[component.table_index].table;
		using component.data;
		for metadata_index in 0..<metadata_count
		{
			offset := metadata_offsets[metadata_index];
			field_type := metadata_types[metadata_index];
			field_size := reflect.size_of_typeid(field_type);
			field_ptr := rawptr(uintptr(components_data[i]) + offset);
			switch metadata_info in metadata[metadata_index]
			{
				case Ref_Metadata:
					// component_data := cast(^u8)components_data[i];

					// log.info(component_handles[metadata_info.component_index]);
					// mem.copy(field_ptr, &component_handles[metadata_info.component_index], field_size);
					// log.info(any{components_data[i], typeid_of(container.Raw_Handle)});
					handle: ^container.Raw_Handle = &component_handles[metadata_info.component_index];
					table_data: ^container.Table_Data = handle.raw_table.table;
					generic_handle := container.Generic_Handle{handle.id, table_data};
					
					target_handle := cast(^container.Generic_Handle)field_ptr;
					target_handle^ = generic_handle;
					//log.info(target_handle);
				case Input_Metadata: 
					prefab_input := inputs[metadata_info.input_index];
					if input_value, ok := input_data[prefab_input.name]; ok {
						if input_value.id == field_type {
							mem.copy(field_ptr, input_value.data, field_size);
						}
						else do log.info("Wrong input type : ", input_value.id);
					}
					else do log.info("Input not found ", prefab_input.name);
					log.info(any{components_data[i], table.type_id});
				case Type_Specific_Metadata:
					pending_metadata := Pending_Metadata{
						metadata_type_id = metadata_info.metadata_type_id,
						metadata = metadata_info.data,
						component_index = i,
						offset_in_component = offset
					};
					log.info("DISPATCH METADATA", metadata_info);
					if metadata_info.field_type_id in metadata_dispatcher^
					{
						container.table_add(&metadata_dispatcher[metadata_info.field_type_id], pending_metadata);
					}
			}
		}
	}

	for component, i in components
	{
		table := &db.tables[component.table_index].table;
		data_ptr := components_data[i];
		log.info(table.type_id, component_sizes[i]);
		log.info("FINAL DATA 1", any{data_ptr, table.type_id});
		component_data := container.handle_get_raw(component_handles[i]);
		mem.copy(component_data, components_data[i], component_sizes[i]);
		log.info("FINAL DATA 2", any{components_data[i], table.type_id});
	}
	log.info("FINISHED");

	success = true;

	return;
}

parse_json_float :: proc(json_data: json.Value) -> f32
{
	#partial switch v in json_data.value
	{
		case json.Integer:
			return f32(v);
		case json.Float:
			return f32(v);
	}
	return 0;
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
				field.type   = s.types[i].id;
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

build_component_model_from_json :: proc(json_data: json.Object, ti: ^runtime.Type_Info, available_component_index: map[string]Registered_Component_Data, result: ^Component_Model_Data)
{
	base_ti := runtime.type_info_base(ti);
	
	for name, value in json_data
	{
		if name == "type" do continue;
		field, field_found := find_struct_field(base_ti, name); // maybe replace with ti ?
		#partial switch t in value.value
		{
			case json.Object:
			{
				//log.info("OBJECT");
			}
			case json.Array:
			{
				if(type_info_of(field.type).size == size_of(f32) * len(t))
				{
					for i := 0; i < len(t); i += 1
					{
						x := parse_json_float(t[i]);
						{
							fieldPtr := uintptr(result.data) + field.offset;
							mem.copy(rawptr(fieldPtr + uintptr(size_of(f32) * i)), &x, size_of(f32));
						}
					}

				}
			}
			case json.Integer:
			case json.Float:
			{
				// TODO : maybe handle f64 ?
				if(field.type == typeid_of(f32))
				{
					value: f32 = f32(t);
					fieldPtr := rawptr(uintptr(result.data) + field.offset);
					mem.copy(fieldPtr, &value, size_of(f32));
				}
			}
			case json.String:
			{
				if(t[0] == '&')
				{
					//log.info("INPUT");
					input_index, parse_success := strconv.parse_int(t[1:]);
					result.metadata[result.metadata_count] = Input_Metadata{input_index};
					result.metadata_offsets[result.metadata_count] = field.offset;
					result.metadata_types[result.metadata_count] = field.type;
					result.metadata_count += 1;
				}
				if(t[0] == '@')
				{
					//log.info("REF");
					ref_name := t[1:];
					log.info("@", ref_name);

					if component_data, ok := available_component_index[ref_name]; ok {
						log.info(component_data);
						result.metadata[result.metadata_count] = Ref_Metadata{component_data.component_index};
						result.metadata_offsets[result.metadata_count] = field.offset;
						result.metadata_types[result.metadata_count] = field.type;
						result.metadata_count += 1;
						log.info("REF ADDED ", ref_name, result.metadata[:result.metadata_count]);
					}
					else do log.info("Missing component", ref_name);
				}
			}
		}
	}
}

load_prefab :: proc(path: string, db: ^container.Database, metadata_dispatcher: Pending_Metadata_Dispatcher, allocator := context.allocator) -> (Prefab, bool)
{
	file, ok := os.read_entire_file(path, context.temp_allocator);
	if ok
	{
		parsed_json, ok := json.parse(file);

		prefab: Prefab;

		json_object: json.Object = parsed_json.value.(json.Object);
		component_count := len(json_object["components"].value.(json.Object));
		
		component_cursor := 0;

		prefab.components = make([]Component_Model, component_count, allocator);

		registered_components := make(map[string]Registered_Component_Data, 10, allocator);

		input_objects := json_object["inputs"].value.(json.Array);
		prefab.inputs = make([]Prefab_Input, len(input_objects), allocator);
		for input_data, index in input_objects
		{
			input_name := input_data.value.(json.Object)["name"].value.(string);
			input_type := input_data.value.(json.Object)["type"].value.(string);
			prefab.inputs[index].name = strings.clone(input_name);
			input_types_map := get_input_types_map(db);
			if input_type in input_types_map
			{
				prefab.inputs[index].type_id = input_types_map[input_type];
			}
		}

		for name, value in json_object["components"].value.(json.Object)
		{
			value_obj := value.value.(json.Object);
			table_name := value_obj["type"].value.(json.String);
			if table, table_index, ok := container.db_get_table(db, table_name); ok
			{
				prefab.components[component_cursor].table_index = table_index;
				ti := type_info_of(table.type_id);
				data := mem.alloc(ti.size, ti.align, allocator);
				prefab.components[component_cursor].data.data = data;

				build_component_model_from_json(value_obj, ti, registered_components, &prefab.components[component_cursor].data);
				prefab.components[component_cursor].id = name;
				registered_components[name] = {component_cursor, table_index};				
			}
			component_cursor += 1;
		}
		delete(registered_components);
		return prefab, true;
	}
	return {}, false;
}

load_dynamic_prefab :: proc(path: string, prefab: ^Dynamic_Prefab, db: ^container.Database, allocator := context.allocator) -> bool
{
	file, ok := os.read_entire_file(path, context.temp_allocator);
	if ok
	{
		parsed_json, ok := json.parse(file);

		json_object: json.Object = parsed_json.value.(json.Object);
		component_count := len(json_object["components"].value.(json.Object));

		clear(&prefab.components);
		clear(&prefab.inputs);

		component_cursor := 0;

		registered_components := make(map[string]Registered_Component_Data, 10, allocator);

		input_objects := json_object["inputs"].value.(json.Array);
		for input_data, index in input_objects
		{
			new_input: Prefab_Input;
			input_name := input_data.value.(json.Object)["name"].value.(string);
			input_type := input_data.value.(json.Object)["type"].value.(string);
			new_input.name = strings.clone(input_name);
			input_types_map := get_input_types_map(db);
			if input_type in input_types_map
			{
				new_input.type_id = input_types_map[input_type];
			}
			append(&prefab.inputs, new_input);
		}

		for name, value in json_object["components"].value.(json.Object)
		{
			value_obj := value.value.(json.Object);
			table_name := value_obj["type"].value.(json.String);
			if table, table_index, ok := container.db_get_table(db, table_name); ok
			{
				new_component: Component_Model;
				new_component.table_index = table_index;

				ti := type_info_of(table.type_id);
				data := mem.alloc(ti.size, ti.align, allocator);
				new_component.data.data = data;
				build_component_model_from_json(value_obj, ti, registered_components, &new_component.data);
				new_component.id = name;
				append(&prefab.components, new_component);
				registered_components[name] = {component_cursor, table_index};				
			}
			component_cursor += 1;
		}
		delete(registered_components);
		return true;
	}
	return false;
}