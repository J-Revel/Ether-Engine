package prefab

import "core:log"
import "core:reflect"
import "core:mem"
import "core:os"
import "core:encoding/json"
import "core:runtime"
import "../container"
import "core:strconv"

table_database_add_init :: proc(db: ^container.Database, name: string, table: ^container.Table($T), size: uint)
{
	log.info("Init table", name, table);
	container.table_init(table, size);
	log.info("table created", name);
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

// TODO Error with transform that is its own parent, must be a bug in the ref handling
prefab_instantiate :: proc(db: ^container.Database, prefab: ^Prefab, input_data: map[string]any) -> (out_components: []Named_Raw_Handle, success: bool)
{
	data_total_size := 0;
	components_data := make([]rawptr, len(prefab.components), context.temp_allocator);
	component_handles := make([]container.Raw_Handle, len(prefab.components), context.allocator); // TODO : can use temp allocator instead ?
	component_sizes := make([]int, len(prefab.components), context.temp_allocator);

	out_components = make([]Named_Raw_Handle, len(prefab.components), context.temp_allocator);

	for component, i in prefab.components
	{
		table := db.tables[component.table_index].table;
		component_sizes[i] = reflect.size_of_typeid(table.type_id);
		components_data[i] = mem.alloc(component_sizes[i], align_of(uintptr), context.temp_allocator);

		log.info("START DATA", components_data[i]);
		log.info(any{components_data[i], table.type_id});
		mem.copy(components_data[i], component.data.data, component_sizes[i]);
		out_components[i].name = component.id;
	}

	for component, i in prefab.components
	{
		table := &db.tables[component.table_index].table;
		ok : bool;
		component_handles[i], ok = container.table_allocate_raw(table);
		out_components[i].value = component_handles[i];

		using component.data;
		for ref_index in 0..<ref_count
		{
			ref := refs[ref_index];
			ref_ptr := rawptr(uintptr(components_data[i]) + ref.field.offset);
			component_data := cast(^u8)components_data[i];
			mem.copy(ref_ptr, &component_handles[ref.component_index], type_info_of(ref.field.type).size);
			log.info(any{components_data[i], typeid_of(container.Raw_Handle)});
			log.info(ref.field.type);
			handle: ^container.Raw_Handle = &component_handles[ref.component_index];
			table_data: ^container.Table_Data = handle.raw_table.table;
			generic_handle := container.Generic_Handle{handle.id, table_data};
			
			field_ptr := rawptr(uintptr(components_data[i]) + ref.field.offset);
			mem.copy(field_ptr, &generic_handle, reflect.size_of_typeid(ref.field.type));
		}

		for input_index in 0..<input_count
		{
			component_input := inputs[input_index];
			prefab_input := prefab.inputs[component_input.input_index];
			if input_value, ok := input_data[prefab_input.name]; ok {
				if input_value.id == component_input.field.type {
					field_ptr := rawptr(uintptr(components_data[i]) + component_input.field.offset);
					mem.copy(field_ptr, input_value.data, reflect.size_of_typeid(component_input.field.type));
				}
				else do log.info("Wrong input value : ", input_value.id, " vs ", component_input.field.type);
			}
			else do log.info("Input not found ", component_input);
			log.info(any{components_data[i], table.type_id});
		}
	}

	for component, i in prefab.components
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
find_struct_field :: proc(T: typeid, name: string) -> (field: reflect.Struct_Field, field_found: bool)
{
	field_found = false;
	ti := runtime.type_info_base(type_info_of(T));
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
				if child_field, ok := find_struct_field(s.types[i].id, name); ok {
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

build_component_model_from_json :: proc(json_data: json.Object, type: typeid, allocator: mem.Allocator, available_component_index: map[string]Registered_Component_Data) -> (result: Component_Model_Data)
{
	ti := type_info_of(type);
	base_ti := runtime.type_info_base(ti);
	result.data = mem.alloc(ti.size, ti.align, allocator);
	
	for name, value in json_data
	{
		if name == "type" do continue;
		field, field_found := find_struct_field(type, name);
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
					result.inputs[result.input_count] = Component_Input{input_index, field};
					result.input_count += 1;
				}
				if(t[0] == '@')
				{
					//log.info("REF");
					ref_name := t[1:];
					log.info("@", ref_name);

					if component_data, ok := available_component_index[ref_name]; ok {
						log.info(component_data);
						result.refs[result.ref_count] = Component_Ref{component_data.component_index, field};
						result.ref_count += 1;
						log.info("REF ADDED ", ref_name, result.refs[:result.ref_count]);
					}
					else do log.info("Missing component", ref_name);
				}
			}
		}
	}

	//log.info(result);
	return result;
}

load_prefab :: proc(path: string, db: ^container.Database, allocator := context.allocator) -> (Prefab, bool)
{
	file, ok := os.read_entire_file(path, context.temp_allocator);
	if ok
	{
		parsed_json, ok := json.parse(file);
		log.info(ok);

		prefab : Prefab;

		json_object: json.Object = parsed_json.value.(json.Object);
		component_count := len(json_object);

		prefab.components = make([]Component_Model, component_count, allocator);

		component_cursor := 0;

		registered_components := make(map[string]Registered_Component_Data, 10, allocator);
		
		for name, value in json_object
		{
			value_obj := value.value.(json.Object);
			log.info(value_obj["type"]);
			table_name := value_obj["type"].value.(json.String);
			if table, table_index, ok := container.db_get_table(db, table_name); ok
			{
				prefab.components[component_cursor].table_index = table_index;
				prefab.components[component_cursor].data = build_component_model_from_json(value_obj, table.type_id, context.temp_allocator, registered_components);
				prefab.components[component_cursor].id = name;
				registered_components[name] = {component_cursor, table_index};				
			}
			component_cursor += 1;
		}
		for component in &prefab.components
		{
			log.info("COMPONENT", component.id);
			log.info(component_refs(&component.data));
			log.info(component_inputs(&component.data));
		}
		return prefab, true;
	}
	return {}, false;
}

component_refs :: inline proc(component: ^Component_Model_Data) -> []Component_Ref
{
	return component.refs[0:component.ref_count];
}

component_inputs :: inline proc(component: ^Component_Model_Data) -> []Component_Input
{
	return component.inputs[0:component.ref_count];
}