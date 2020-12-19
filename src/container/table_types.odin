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

Generic_Handle :: struct
{
	id: int,
	table_data: ^Table_Data
}

// TODO : turn into Raw_Table with raw data and 
Table_Data :: struct
{
	data: rawptr,
	allocation: Bit_Array,
	allocator: mem.Allocator,
}

Table :: struct(T: typeid)
{
	using raw: Table_Data,
}

Raw_Table :: struct
{
	using table: ^Table_Data,
	type_id: typeid,
	handle_type_id: typeid,
}

Table_Iterator :: struct(T: typeid)
{
	table: ^Table(T),
	cursor: int,
}