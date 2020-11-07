package table

import "core:log"
import "core:reflect"
import "core:mem"
import "core:os"
import "core:encoding/json"
import "core:runtime"

Database_Named_Table :: struct { name: string, table: Database_Table };
Database :: [dynamic]Database_Named_Table;
Database_Table :: struct
{
	using table: ^Raw_Table,
	type: typeid,
}

Component_Ref :: struct
{
	component_index: int,
	field: reflect.Struct_Field,
}

Component_Model_Data :: struct
{
	data: rawptr,
	refs: []Component_Ref,
	inputs: []Component_Input,
}

Component_Model :: struct
{
	id: string,
	table_index: int,
	data: Component_Model_Data,
}

Component_Input :: struct
{
	name: string,
	field: reflect.Struct_Field,
}

Prefab :: struct
{
	components: []Component_Model,
}

Named_Component :: struct(T: typeid)
{
	name: string,
	value: Handle(T)
}

Named_Element :: struct(T: typeid)
{
	name: string,
	value: T
}

Named_Raw_Handle :: Named_Element(Raw_Handle);

table_database_add :: proc(db: ^Database, name: string, table: ^Table($T))
{
	named_table := Database_Named_Table{name, Database_Table{table, typeid_of(T)}};
	append(db, named_table);
}

table_database_add_init :: proc(db: ^Database, name: string, table: ^Table($T), size: uint)
{
	table_init(table, size);
	named_table := Database_Named_Table{name, Database_Table{table, typeid_of(T)}};
	append(db, named_table);
}

prefab_instantiate :: proc(db: ^Database, prefab: ^Prefab, input_data: map[string]any) -> (out_components: []Named_Raw_Handle, success: bool)
{
	data_total_size := 0;
	components_data := make([]rawptr, len(prefab.components), context.temp_allocator);
	component_handles := make([]Raw_Handle, len(prefab.components), context.temp_allocator);
	component_sizes := make([]int, len(prefab.components), context.temp_allocator);

	out_components = make([]Named_Raw_Handle, len(prefab.components), context.temp_allocator);

	for component, i in prefab.components
	{
		table := db[component.table_index].table;
		component_sizes[i] = reflect.size_of_typeid(table.type);
		components_data[i] = mem.alloc(component_sizes[i], align_of(uintptr), context.temp_allocator);
		mem.copy(components_data[i], component.data.data, component_sizes[i]);
		out_components[i].name = component.id;
	}

	for component, i in prefab.components
	{
		table := db[component.table_index].table;
		ok : bool;
		component_handles[i], ok = table_allocate_raw(table, reflect.size_of_typeid(table.type));
		out_components[i].value = component_handles[i];

		for ref in component.data.refs
		{
			fieldPtr := rawptr(uintptr(components_data[i]) + ref.field.offset);
			//log.info(ref);
			mem.copy(fieldPtr, &component_handles[ref.component_index], size_of(Raw_Handle));
		}

		for input in component.data.inputs
		{
			if input_value, ok := input_data[input.name]; ok {
				if input_value.id == input.field.type {
					field_ptr := rawptr(uintptr(components_data[i]) + input.field.offset);
					mem.copy(field_ptr, input_value.data, reflect.size_of_typeid(input.field.type));
				}
				else do log.info("Wrong input value : ", input_value.id, " vs ", input.field.type);
			}
			else do log.info("Input not found ", input);
		}
	}

	for component, i in prefab.components
	{
		component_data := handle_get_raw(component_handles[i], component_sizes[i]);
		mem.copy(component_data, components_data[i], component_sizes[i]);
	}

	success = true;

	return;
}

db_get_table :: proc(db: Database, name: string) -> (Database_Table, int, bool)
{
	for table, table_index in db
	{
		if table.name == name
		{
			return table.table, table_index, true;
		}
	}
	return {}, 0, false;
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
	refs : [dynamic]Component_Ref;
	inputs : [dynamic]Component_Input;
	
	for name, value in json_data
	{
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
					input_name := t[1:];
					append(&inputs, Component_Input{input_name, field});
				}
				if(t[0] == '@')
				{
					//log.info("REF");
					ref_name := t[1:];

					if component_data, ok := available_component_index[ref_name]; ok {
						append(&refs, Component_Ref{component_data.component_index, field});
					}
					else do log.info("Missing component", ref_name);
				}
			}
		}
	}
	result.inputs = make([]Component_Input, len(inputs), allocator);
	for input, index in inputs do result.inputs[index] = inputs[index];
	result.refs = make([]Component_Ref, len(refs), allocator);
	for ref, index in refs do result.refs[index] = refs[index];

	//log.info(result);
	return result;
}

Registered_Component_Data :: struct
{
	component_index: int,
	table_index: int,
}

load_prefab :: proc(path: string, db: Database, allocator := context.allocator) -> (Prefab, bool)
{
	file, ok := os.read_entire_file(path);
	if ok
	{
		parsed, ok := json.parse(file);

		prefab : Prefab;

		component_count := len(parsed.value.(json.Object));

		prefab.components = make([]Component_Model, component_count, context.temp_allocator);

		component_cursor := 0;
		parsed_object := parsed.value.(json.Object);

		registered_components := make(map[string]Registered_Component_Data, 10, context.temp_allocator);
		
		for name, value in parsed_object
		{
			table, table_index, ok := db_get_table(db, name);
			if(ok)
			{
				prefab.components[component_cursor].table_index = table_index;
				prefab.components[component_cursor].data = build_component_model_from_json(value.value.(json.Object), table.type, context.temp_allocator, registered_components);
				prefab.components[component_cursor].id = name;
				registered_components[name] = {component_cursor, table_index};				
			}
			component_cursor += 1;
		}

		//l_b := gameplay.Loading_Building{Handle(Building){0, nil}, 0};
		//wave_emitter := Wave_Emitter{Handle(Loading_Building){0, nil}, 0, math.PI / 10};
		//prefab.components[0] = {0, &building};
		//prefab.components[1] = {1, &l_b};
		//prefab.components[2] = {4, &wave_emitter};

		//prefab.refs = make([]Component_Ref, 2, context.temp_allocator);
		//test_offset := (reflect.struct_field_by_name(typeid_of(Loading_Building), "building").offset);
		//prefab.refs[0] = {1, int(test_offset), 0};

		//test_offset = (reflect.struct_field_by_name(typeid_of(Wave_Emitter), "loading_building").offset);
		//prefab.refs[1] = {2, int(test_offset), 1};
	
		//log.info(parsed.value.(json.Object)["building"].value.(json.Object)["size"].value.(json.Array)[0].value.(f64));
		return prefab, true;
	}
	return {}, false;
}
