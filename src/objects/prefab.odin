package prefab

import "core:log"
import "core:reflect"
import "core:mem"
import "core:os"
import "core:encoding/json"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:slice"

import "../container"
import "../serialization"

default_input_types := [?]Prefab_Input{
	{"int", Primitive_Type(typeid_of(int))}, 
	{"u32", Primitive_Type(typeid_of(u32))}, 
	{"i32", Primitive_Type(typeid_of(i32))}, 
	{"float", Primitive_Type(typeid_of(f32))}, 
	{"vec2", Primitive_Type(typeid_of([2]f32))},
};

get_input_types_list :: proc(prefab_tables: ^Named_Table_List, allocator := context.allocator) -> []Prefab_Input
{
	result := make([dynamic]Prefab_Input, allocator);
	
	for type in default_input_types
	{
		append(&result, type);
	}

	for component_type_id in &prefab_tables.component_types
	{
		append(&result, Prefab_Input{component_type_id.name, component_type_id.handle_type_id});
	}
	return result[:];	
}

is_same_input_type :: proc(first: Input_Type, second: Input_Type) -> bool
{
	first_type_id, first_primitive := first.(Primitive_Type);
	sec_type_id, sec_primitive := second.(Primitive_Type);
	if first == nil || second == nil || first_primitive != sec_primitive do return false;
	else if first_primitive do return first_type_id == sec_type_id;
	else do return first.(Component_Type) == second.(Component_Type);
}

can_use_input_type :: proc(field_type_id: typeid, input_type: Input_Type) -> bool
{
	switch type in input_type
	{
		case Primitive_Type:
			return type == field_type_id;
		case Component_Type:
			return type.handle_type_id == field_type_id;
	}
	return false;
}

is_input_type :: proc(prefab_tables: ^Named_Table_List, type_id: typeid) -> bool
{
	for input_type in default_input_types
	{
		switch type in input_type.type
		{
			case Primitive_Type:
				if type_id == type do return true;
			case Component_Type:
				if type_id == type.handle_type_id do return true;
		}
		
	}
	for component_type in prefab_tables.component_types
	{
		if component_type.handle_type_id == type_id do return true;
	}
	return false;
}

get_input_types_map :: proc(prefab_tables: ^Named_Table_List, allocator := context.allocator) -> map[string]Input_Type
{
	result := make(map[string]Input_Type, 100, allocator);
	
	for default_type in default_input_types
	{
		result[default_type.name] = default_type.type;
	}

	for type in &prefab_tables.component_types
	{
		result[type.name] = type.handle_type_id;
	}
	return result;	
}

table_database_add_init :: proc(prefab_tables: ^Named_Table_List, name: string, table: ^container.Table($T), size: uint)
{
	container.table_init(table, size);
	append(&prefab_tables.tables, Named_Table{name, container.to_raw_table(table)});
	type_already_added := false;
	for type in prefab_tables.component_types 
	{
		if type.handle_type_id == typeid_of(container.Handle(T))
		{
			type_already_added = true;
		}
	}
	if !type_already_added do append(&prefab_tables.component_types, Component_Type{
		name, 
		T, 
		typeid_of(container.Handle(T)),
	});
	log.info("Create database", name);
}

prefab_instantiate_dynamic :: proc(
	prefab_tables: ^Named_Table_List,
	prefab: ^Dynamic_Prefab,
	input_data: map[string]any,
	metadata_dispatcher: ^Instantiate_Metadata_Dispatcher,
	scene_database: ^container.Database,
) -> (
	out_components: []Named_Raw_Handle, 
	out_transforms: []Prefab_Instance_Transform, 
	success: bool,
)
{
	return components_instantiate(
		prefab_tables,
		&prefab.transform_hierarchy,
		prefab.components[:],
		prefab.inputs[:],
		input_data,
		metadata_dispatcher,
		scene_database,
	);
}

prefab_instantiate :: proc(
	prefab_tables: ^Named_Table_List,
	prefab: ^Prefab,
	input_data: map[string]any,
	metadata_dispatcher: ^Instantiate_Metadata_Dispatcher,
	scene_database: ^container.Database,
) -> (out_components: []Named_Raw_Handle, 
	out_transforms: []Prefab_Instance_Transform, 
	success: bool)
{
	return components_instantiate(
		prefab_tables,
		&prefab.transform_hierarchy,
		prefab.components,
		prefab.inputs,
		input_data,
		metadata_dispatcher,
		scene_database,
	);
}

components_instantiate :: proc(
	prefab_tables: ^Named_Table_List, 
	prefab_transforms: ^Transform_Hierarchy,
	components: []Component_Model,
	inputs: []Prefab_Input,
	input_data: map[string]any,
	metadata_dispatcher: ^Instantiate_Metadata_Dispatcher,
	scene_database: ^container.Database,
) -> (
	out_components: []Named_Raw_Handle, 
	out_transforms: []Prefab_Instance_Transform, 
	success: bool,
)
{
	data_total_size := 0;
	components_data := make([]rawptr, len(components), context.temp_allocator);

	// TODO : used non temp allocator before => to check ?
	component_handles := make([]container.Raw_Handle, len(components), context.temp_allocator);
	component_sizes := make([]int, len(components), context.temp_allocator);

	out_components = make([]Named_Raw_Handle, len(components), context.temp_allocator);

	scene_transform_hierarchy := container.database_get(scene_database, Transform_Hierarchy);
	
	stack: [dynamic]Prefab_Instance_Transform;
	spawned_transforms: [dynamic]Prefab_Instance_Transform;

	for cursor := prefab_transforms.first_element_index; cursor > 0; cursor = prefab_transforms.next_elements[cursor-1]
	{
		using prefab_transforms;
		current_level := levels[cursor-1];
		if current_level >= len(stack)
		{
			append(&stack, Prefab_Instance_Transform{});
		}
		local_transform := prefab_transforms.transforms[cursor-1];
		name := prefab_transforms.names[cursor-1];

		new_stack_element := Prefab_Instance_Transform{uid = uids[cursor-1]};
		if current_level == 0
		{
			new_stack_element.handle = transform_hierarchy_add_root(scene_transform_hierarchy, local_transform, name);
		}
		else
		{
			new_stack_element.handle = transform_hierarchy_add_leaf(scene_transform_hierarchy, local_transform, stack[current_level-1].handle, name);
		}
		append(&spawned_transforms, new_stack_element);
		stack[current_level] = new_stack_element;
	}

	out_transforms = slice.clone(spawned_transforms[:], context.temp_allocator);

	for component, i in components
	{
		table := prefab_tables.tables[component.table_index].table;
		component_sizes[i] = reflect.size_of_typeid(table.type_id);
		// TODO : check alignment
		components_data[i] = mem.alloc(component_sizes[i], align_of(uintptr), context.temp_allocator);

		mem.copy(components_data[i], component.data.data, component_sizes[i]);
		out_components[i].name = component.id;
	}

	for component, i in components
	{
		table := &prefab_tables.tables[component.table_index].table;
		ok : bool;
		component_handles[i], ok = container.table_allocate_raw(table);
		out_components[i].value = component_handles[i];

	}
	for component, i in components
	{
		table := &prefab_tables.tables[component.table_index].table;
		using component.data;
		for metadata_index in 0..<metadata_count
		{
			offset := metadata_offsets[metadata_index];
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
					input_value, ok := input_data[prefab_input.name];
					if ok
					{
						switch input_type in prefab_input.type
						{
							case Primitive_Type:
								mem.copy(field_ptr, input_value.data, type_info_of(input_type).size);
							case Component_Type:
								input_data_type_id := input_type.handle_type_id;
								target_handle := cast(^container.Generic_Handle)field_ptr;
								input_handle := cast(^container.Raw_Handle)input_value.data;
								log.info("-----");
								log.info(any{components_data[i], table.type_id}, input_handle);
								table_data: ^container.Table_Data = input_handle.raw_table.table;
								target_handle^ = container.Generic_Handle{input_handle.id, table_data};
								log.info(any{components_data[i], table.type_id});
						}
						//if input_value.id == input_data_type_id {
							
						//}
						
					}
				case Type_Specific_Metadata:
					pending_metadata := Instantiate_Metadata{
						metadata_type_id = metadata_info.metadata_type_id,
						metadata = metadata_info.data,
						component_index = i,
						offset_in_component = offset,
					};
					if metadata_info.field_type_id in metadata_dispatcher^
					{
						container.table_add(&metadata_dispatcher[metadata_info.field_type_id], pending_metadata);
					}
			}
		}
	}

	for component, i in components
	{
		table := &prefab_tables.tables[component.table_index].table;
		data_ptr := components_data[i];
		component_data := container.handle_get_raw(component_handles[i]);
		mem.copy(component_data, components_data[i], component_sizes[i]);
	}

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

parse_json_int :: proc(json_data: json.Value) -> int
{

	#partial switch v in json_data.value
	{
		case json.Integer:
			return int(v);
		case json.Float:
			return int(v);
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


// TODO : simplify function signature
build_component_model_from_json :: proc(
		json_data: json.Object, 
		ti: ^runtime.Type_Info, 
		available_component_index: map[string]Registered_Component_Data,
		metadata_dispatcher: ^Load_Metadata_Dispatcher,
		result: ^Component_Model_Data,
		component_index: int)
{
	base_ti := runtime.type_info_base(ti);
	
	for name, value in json_data
	{
		if name == "type" do continue;
		field, field_found := find_struct_field(base_ti, name);
		if field.type in metadata_dispatcher^
		{
			metadata: Load_Metadata;
			dispatcher_entry := &(metadata_dispatcher^)[field.type];

			metadata.data_type_id = dispatcher_entry.type_id;
			metadata.offset_in_component = field.offset;
			metadata_type_info := type_info_of(dispatcher_entry.type_id);
			// TODO : check memory leak (context.allocator would make the strings temp)
			metadata.data = serialization.json_read_struct(value.value.(json.Object), metadata_type_info, context.temp_allocator);
			metadata.component_index = component_index;

			container.table_add(&dispatcher_entry.table, metadata);
		}
		else
		{
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
}

load_prefab :: proc(
	path: string,
	prefab_tables: ^Named_Table_List,
	metadata_dispatcher: ^Load_Metadata_Dispatcher,
	allocator := context.allocator,
) -> (Prefab, bool)
{
	file, ok := os.read_entire_file(path, context.temp_allocator);
	if ok
	{
		parsed_json, ok := json.parse(file);

		prefab: Prefab;

		json_object: json.Object = parsed_json.value.(json.Object);
		component_count := len(json_object["components"].value.(json.Object));
		
		transform_hierarchy_init(&prefab.transform_hierarchy, 100);

		transform_array := json_object["transforms"].value.(json.Array);
		for transform_json, index in transform_array
		{
			main_json_object: json.Object = transform_json.value.(json.Object);
			transform_json_object := main_json_object["transform"].value.(json.Object);
			transform_type_info := type_info_of(Transform);
			log.info("load transform", index);
			parsed_transform := serialization.json_read_struct(
				transform_json_object,
				transform_type_info,
				context.temp_allocator);
			using prefab.transform_hierarchy;
			transform_instance := (cast(^Transform)parsed_transform)^;
			log.info(transform_instance);
			append(&transforms, transform_instance);
			append(&names, main_json_object["name"].value.(json.String));
			append(&levels, parse_json_int(main_json_object["level"]));
			append(&next_elements, 0);
			if index > 0 do next_elements[index-1] = index + 1;
			append(&previous_elements, index);
			new_transform_handle, ok := container.table_add(&element_index_table, index+1);
			assert(ok);
			append(&handles, new_transform_handle);
			uid := parse_json_int(main_json_object["uid"]);
			append(&uids, cast(Transform_UID)uid);
			log.info(uids);
			log.info(next_elements);
			log.info(previous_elements);
		}
		prefab.transform_hierarchy.first_element_index = 1;
		prefab.transform_hierarchy.last_element_index = len(prefab.transform_hierarchy.handles);

		log.info(prefab.transform_hierarchy);
		prefab.components = make([]Component_Model, component_count, allocator);

		registered_components: map[string]Registered_Component_Data;

		input_objects := json_object["inputs"].value.(json.Array);
		prefab.inputs = make([]Prefab_Input, len(input_objects), allocator);
		for input_data, index in input_objects
		{
			input_name := input_data.value.(json.Object)["name"].value.(string);
			input_type := input_data.value.(json.Object)["type"].value.(string);
			prefab.inputs[index].name = strings.clone(input_name);
			input_types_map := get_input_types_map(prefab_tables);
			if input_type in input_types_map
			{
				prefab.inputs[index].type = input_types_map[input_type];
				log.info("INPUT TYPE", prefab.inputs[index].type);
			}
		}


		component_cursor := 0;
		for name, value in json_object["components"].value.(json.Object)
		{
			value_obj := value.value.(json.Object);
			table_name := value_obj["type"].value.(json.String);
			if table, table_index, ok := db_get_table(prefab_tables, table_name); ok
			{
				registered_components[name] = {component_cursor, table_index};				
				component_cursor += 1;
			}
		}

		component_cursor = 0;
		for name, value in json_object["components"].value.(json.Object)
		{
			value_obj := value.value.(json.Object);
			table_name := value_obj["type"].value.(json.String);
			if table, table_index, ok := db_get_table(prefab_tables, table_name); ok
			{
				prefab.components[component_cursor].table_index = table_index;
				ti := type_info_of(table.type_id);
				data := mem.alloc(ti.size, ti.align, allocator);
				prefab.components[component_cursor].data.data = data;

				build_component_model_from_json(value_obj, ti, registered_components, metadata_dispatcher, &prefab.components[component_cursor].data, component_cursor);
				
				prefab.components[component_cursor].id = name;
			}
			component_cursor += 1;
		}
		return prefab, true;
	}
	return {}, false;
}

load_dynamic_prefab :: proc(path: string, prefab: ^Dynamic_Prefab, prefab_tables: ^Named_Table_List, metadata_dispatcher: ^Load_Metadata_Dispatcher, allocator := context.allocator) -> bool
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
			input_types_map := get_input_types_map(prefab_tables);
			if input_type in input_types_map
			{
				new_input.type = input_types_map[input_type];
			}
			append(&prefab.inputs, new_input);
		}

		for name, value in json_object["components"].value.(json.Object)
		{
			value_obj := value.value.(json.Object);
			table_name := value_obj["type"].value.(json.String);
			if table, table_index, ok := db_get_table(prefab_tables, table_name); ok
			{
				new_component: Component_Model;
				new_component.table_index = table_index;

				ti := type_info_of(table.type_id);
				data := mem.alloc(ti.size, ti.align, allocator);
				new_component.data.data = data;
				build_component_model_from_json(value_obj, ti, registered_components, metadata_dispatcher, &new_component.data, component_cursor);
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

init_instantiate_metadata_dispatch_type :: #force_inline proc(metadata_dispatcher: ^Instantiate_Metadata_Dispatcher, $T: typeid) -> ^container.Table(Instantiate_Metadata)
{
	metadata_dispatcher[typeid_of(T)] = {};
	dispatch_table := &metadata_dispatcher[typeid_of(T)];
	container.table_init(dispatch_table);
	return dispatch_table;
}

init_load_metadata_dispatch_type :: #force_inline proc(metadata_dispatcher: ^Load_Metadata_Dispatcher, $T: typeid, $U: typeid) -> ^container.Table(Load_Metadata)
{
	metadata_dispatcher[typeid_of(T)] = {type_id=U};
	dispatch_table := &metadata_dispatcher[typeid_of(T)];
	container.table_init(&dispatch_table.table);
	return &dispatch_table.table;
}


// TODO : rename
db_get_table :: proc(prefab_tables: ^Named_Table_List, name: string) -> (container.Raw_Table, int, bool)
{
	for table, table_index in prefab_tables.tables
	{
		if table.name == name
		{
			return table.table, table_index, true;
		}
	}
	return {}, 0, false;
}

db_get_tables_of_type :: proc(prefab_tables: ^Named_Table_List, type_id: typeid, allocator := context.temp_allocator) -> []Named_Table
{
	result := make([]Named_Table, len(prefab_tables.tables), allocator);
	result_count := 0;
	for named_table in &prefab_tables.tables
	{
		if named_table.table.type_id == type_id
		{
			result[result_count] = named_table;
			result_count += 1;
		}
	}
	return result[0:result_count];
}
