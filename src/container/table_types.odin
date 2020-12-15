package table

import "core:mem"

Database_Named_Table :: struct { name: string, table: Raw_Table };
Database :: struct {
	tables: [dynamic]Database_Named_Table,
	component_types: [dynamic]Named_Element(typeid),
}

Named_Element :: struct(T: typeid)
{
	name: string,
	value: T
}

Bit_Array :: []u32;

Raw_Handle :: struct
{
	id: int,
	raw_table: ^Raw_Table
}

Handle :: struct(T: typeid)
{
	id: int,
	table: ^Table(T)
}

Raw_Table :: struct
{
	data: rawptr,
	allocation: ^Bit_Array,
	allocator: mem.Allocator,
	type_id: typeid,
	handle_type_id: typeid
}

Table :: struct(T: typeid)
{
	data: rawptr,
	allocation: Bit_Array,
	allocator: mem.Allocator
}

Table_Iterator :: struct(T: typeid)
{
	table: ^Table(T),
	cursor: int,
}