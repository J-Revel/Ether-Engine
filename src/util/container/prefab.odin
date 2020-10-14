package table

import "core:log"
import "core:reflect"
import "core:mem"
import "core:os"
import "core:encoding/json"

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
	component_offset: int,
	ref_target_index: int,
}

Component_Input :: struct
{
	offset: int,
	size: int,
	data: rawptr,
}

Component_Model :: struct
{
	table_index: int,
	data: rawptr,
}

Prefab :: struct
{
	components: []Component_Model,
	refs: []Component_Ref,
}

table_database_add :: proc(db: ^Database, name: string, table: ^Table($T))
{
	named_table := Database_Named_Table{name, Database_Table{table, typeid_of(T)}};
	append(db, named_table);
}

prefab_instantiate :: proc(db: ^Database, prefab: Prefab) -> bool
{
	data_total_size := 0;
	components_data := make([]rawptr, len(prefab.components), context.temp_allocator);
	component_handles := make([]Raw_Handle, len(prefab.components), context.temp_allocator);
	component_sizes := make([]int, len(prefab.components), context.temp_allocator);

	for component, i in prefab.components
	{
		table := db[component.table_index].table;
		component_sizes[i] = reflect.size_of_typeid(table.type);
		components_data[i] = mem.alloc(component_sizes[i], align_of(uintptr), context.temp_allocator);
		mem.copy(components_data[i], component.data, component_sizes[i]);
	}

	for component, i in prefab.components
	{
		table := db[component.table_index].table;
		ok : bool;
		component_handles[i], ok = table_allocate_raw(table, reflect.size_of_typeid(table.type));
		for ref in prefab.refs
		{
			if ref.component_index == i
			{
				mem.copy(rawptr(uintptr(int(uintptr(components_data[i])) + ref.component_offset)), &component_handles[ref.ref_target_index], size_of(Raw_Handle));
			}
		}
	}

	for component, i in prefab.components
	{
		component_data := handle_get_raw(component_handles[i], component_sizes[i]);
		mem.copy(component_data, components_data[i], component_sizes[i]);
	}

	return true;
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

json_value_to_f32 :: proc(value : json.Value) -> f32
{
	#partial switch v in value.value
	{
		case json.Float:
		{
			return f32(v);
		}
		case json.Integer:
		{
			return f32(v);
		}
	}
	return 0;
}

build_struct_inputs_from_json :: proc(json_data: json.Object, type: typeid, allocator: mem.Allocator) -> []Component_Input
{
	result := mem.alloc(size_of(type), align_of(type), allocator);
	for name, value in json_data
	{
		#partial switch t in value.value
		{
			case json.Object:
			{
				log.info("OBJECT");
			}
			case json.Array:
			{
				if len(t) == 2
				{
					vector: [2]f32;
					log.info(t[0].value);
					vector.x = json_value_to_f32(t[0]);
					vector.y = json_value_to_f32(t[1]);



					log.info("[2]f32", vector);
				}
			}
			case json.Float:
			{
				log.info("FLOAT", f32(t));
			}
			case json.String:
			{
				log.info("STRING");
			}
		}
	}
	return result;
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
		
		for name, value in parsed_object
		{
			table, table_index, ok := db_get_table(db, name);
			log.info(name);
			if(ok)
			{
				prefab.components[component_cursor].table_index = table_index;
				data := build_struct_from_json(value.value.(json.Object), table.type, context.temp_allocator);
			}
			component_cursor += 1;
		}

		log.info(prefab);
		assert(false);
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