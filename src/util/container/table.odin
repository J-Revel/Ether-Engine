package util

import "core:mem"
import "core:runtime"
import "core:log"

Bit_Array :: struct
{
	data: ^u32,
	cap: uint // u32 slots count
}

bit_array_init :: proc(a: ^Bit_Array, cap: uint, allocator := context.allocator)
{
	a.data = cast(^u32)mem.alloc(size_of(u32) * cast(int)cap, align_of(u32), allocator);
	a.cap = cap;
}

bit_array_set :: proc(array: ^Bit_Array, bit: uint, value: bool)
{
	s := transmute([]u32) mem.Raw_Slice{array.data, cast(int)array.cap};
	array_index := bit / 32;
	bit_index := bit % 32;
	if value do s[array_index] |= 1 << bit_index;
	else do s[array_index] &= ~(1 << bit_index); 
}

bit_array_get :: proc(array: ^Bit_Array, bit: uint) -> bool
{
	s := transmute([]u32) mem.Raw_Slice{array.data, cast(int)array.cap};
	array_index := bit / 32;
	bit_index := bit % 32;
	return (s[array_index] & (1 << bit_index)) > 0;
}

bit_array_allocate :: proc(array: ^Bit_Array) -> (uint, bool)
{
	s := transmute([]u32) mem.Raw_Slice{array.data, cast(int)array.cap};
	for i in 0..<cast(uint)array.cap * 32
	{
		array_index : uint = i / 32;
		bit_index : uint = i % 32;
		bit_flag : u32 = cast(u32)(1 << bit_index);
		if (s[cast(int)array_index] & bit_flag) == 0
		{
			s[array_index] |= bit_flag;
			log.info(s[array_index]);
			return i, true;
		}
	}
	return 0, false;
}

Handle :: struct(T: typeid)
{
	id: uint
}

Table :: struct(T: typeid)
{
	data: ^T,
	allocation: Bit_Array,

	allocator: mem.Allocator,
}

Table_Iterator :: struct(T: typeid)
{
	table: ^Table(T),
	cursor: uint,
}

table_init :: proc{table_init_none, table_init_cap};

table_init_none :: proc(a: ^$A/Table, allocator:= context.allocator)
{
	table_init_cap(a, 100, allocator);
}

table_init_cap :: proc(a: ^$A/Table($V), cap: uint, allocator := context.allocator)
{
	a.allocator = allocator;

	a.data = (^V)(mem.alloc(size_of(V) * cast(int)cap, align_of(V), allocator));
	bit_array_init(&a.allocation, (cap + 31) / 32, allocator);
}

table_add :: proc(table: ^$A/Table($V), value: V) -> (Handle(V), bool)
{
	index, ok := bit_array_allocate(&table.allocation);
	log.info(index);
	if ok
	{
		mem.ptr_offset(table.data, cast(int)index)^ = value;
		log.info(mem.ptr_offset(table.data, cast(int)index)^);
	}
	return Handle(V){index}, ok;
}

table_delete :: proc(a: $A/Table)
{
	mem.free(a.data, a.allocator);
}

table_iterator :: proc(table: ^$A/Table($T)) -> Table_Iterator(T)
{
	cursor : uint = 0;
	for ;cursor < table.allocation.cap * 32 && !bit_array_get(&table.allocation, cursor); cursor += 1 {}
	return Table_Iterator(T){table, cursor};
}

table_iterate :: proc(it: ^$A/Table_Iterator($T)) -> (value: Handle(T), ok: bool)
{
	if it.cursor < it.table.allocation.cap * 32
	{
		ok = true;
	}
	value = Handle(T){it.cursor};
	it.cursor += 1;
	for it.cursor < it.table.allocation.cap * 32 && !bit_array_get(&it.table.allocation, it.cursor)
	{
		it.cursor += 1;
	}
	return;
}

table_get :: proc(table: ^$A/Table($V), index: Handle(V)) -> ^V
{
	return mem.ptr_offset(table.data, cast(int)index.id);
}

table_elements :: proc(table: ^$A/Table($V)) -> []Handle(V)
{
	result_data := cast(^Handle(V)) mem.alloc(cast(int)(size_of(Handle(V)) * table.allocation.cap * 32), align_of(Handle(V)), table.allocator);
	result_count := 0;
	for i in 0..<table.allocation.cap * 32
	{
		if bit_array_get(&table.allocation, cast(uint)i)
		{
			element := mem.ptr_offset(result_data, int(i));
			element^.id = i;
			result_count += 1;
		}

	}
	return transmute([]Handle(V)) mem.Raw_Slice{result_data, result_count};
}