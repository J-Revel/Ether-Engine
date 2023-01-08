package util

import "core:mem"

Named_Element :: struct(T: typeid)
{
	name: string,
	value: T,
}

Bit_Array :: []u32;

Raw_Handle :: struct
{
	id: uint,
	raw_table: ^Raw_Table,
}

Handle :: struct(T: typeid)
{
	id: int,
	table: ^Table(T),
}

Generic_Handle :: struct
{
	id: int,
	table_data: ^Table_Data,
}

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

Database :: map[typeid]rawptr;
