package util

import "core:log"
import "core:reflect"
import "core:mem"

vec2 :: [2]f32;

Planet_Harmonic :: struct
{
    f, offset: f32
}

Config :: struct
{
    r: f32,
    harmonics: [dynamic]Planet_Harmonic
}

Planet :: struct
{
    pos: vec2,
    using config: Config
}

Grounded_Hitbox :: struct
{
    planet: ^Planet,
    size: vec2,
    angle: f32
}

Building_Render_Data :: struct
{
    render_size: vec2,
    color: [4]f32,
}


Building :: struct
{
    using hitbox: Grounded_Hitbox,
    render_data: ^Building_Render_Data,
}

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
				mem.copy(rawptr(uintptr(int(uintptr(components_data[i])) + ref.component_offset)), &component_handles[i], size_of(Raw_Handle));
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