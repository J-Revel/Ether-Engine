package table

import "core:mem"
import "core:runtime"
import "core:log"

Bit_Array :: struct
{
	data: ^u32,
	cap: uint, // u32 slots count
	allocator: mem.Allocator,
}

bit_array_init :: proc(a: ^Bit_Array, cap: uint, allocator := context.allocator)
{
	a.data = cast(^u32)mem.alloc(size_of(u32) * cast(int)cap, align_of(u32), allocator);
	a.cap = cap;
	a.allocator = allocator;
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
	array_index := bit / 32;
	bit_index := bit % 32;
	value := mem.ptr_offset(array.data, cast(int)array_index);
	return (value^ & (1 << bit_index)) > 0;
}

bit_array_allocate :: proc(array: ^Bit_Array) -> (uint, bool)
{
	for i in 0..<cast(uint)array.cap * 32
	{
		array_index : uint = i / 32;
		bit_index : uint = i % 32;
		bit_flag : u32 = cast(u32)(1 << bit_index);
		value := mem.ptr_offset(array.data, cast(int)array_index);
		if (value^ & bit_flag) == 0
		{
			value^ |= bit_flag;
			return i, true;
		}
	}
	return 0, false;
}

Raw_Handle :: struct
{
	id: uint,
	raw_table: ^Raw_Table
}

Handle :: struct(T: typeid)
{
	id: uint,
	table: ^Table(T)
}

Raw_Table :: struct
{
	data: rawptr,
	allocation: Bit_Array,
	allocator: mem.Allocator
}

Table :: struct(T: typeid)
{
	using raw: Raw_Table
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

	a.data = (mem.alloc(size_of(V) * cast(int)cap, align_of(V), allocator));
	bit_array_init(&a.allocation, (cap + 31) / 32, allocator);
}

table_add :: proc(table: ^$A/Table($T), value: T) -> (Handle(T), bool)
{
	index, ok := bit_array_allocate(&table.allocation);
	if ok
	{
		mem.ptr_offset(cast(^T)table.data, cast(int)index)^ = value;
	}
	return Handle(T){index + 1, table}, ok;
}

ptr_offset :: inline proc(ptr: uintptr, n: int, type_size: int) -> uintptr {
	new := int(ptr) + type_size * n;
	return uintptr(new);
}

table_add_raw :: proc(table: ^Raw_Table, value: any, type_size: int) -> (Raw_Handle, bool)
{
	index, ok := bit_array_allocate(&table.allocation);
	if ok
	{
		mem.copy(rawptr(ptr_offset(uintptr(table.data), int(index), type_size)), value.data, type_size);
	}
	return Raw_Handle{index + 1, table}, ok;
}

// like table_add_raw but does not set the value yed
table_allocate_raw :: proc(table: ^Raw_Table, type_size: int) -> (Raw_Handle, bool)
{
	index, ok := bit_array_allocate(&table.allocation);
	return Raw_Handle{index + 1, table}, ok;
}

invalid_handle :: proc(table: ^$A/Table($T)) -> Handle(T)
{
	return Handle(T){0, table};
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

iterate :: proc{ table_iterate };

table_iterate :: proc(it: ^$A/Table_Iterator($T)) -> (value: ^T, id: Handle(T), ok: bool)
{
	if it.cursor < it.table.allocation.cap * 32
	{
		ok = true;
	}
	id = Handle(T){it.cursor + 1, it.table};
	value = table_get(it.table, id);
	it.cursor += 1;
	for it.cursor < it.table.allocation.cap * 32 && !bit_array_get(&it.table.allocation, it.cursor)
	{
		it.cursor += 1;
	}
	return;
}

table_get :: proc(table: ^$A/Table($T), index: Handle(T)) -> ^T
{
	return mem.ptr_offset(cast(^T)table.data, cast(int)index.id - 1);
}

table_get_raw :: proc(table: ^Raw_Table, index: Raw_Handle, type_size: int) -> rawptr
{
	return rawptr(uintptr(int(uintptr(table.data)) + type_size * int(index.id - 1)));
}

handle_get :: proc(handle: $A/Handle($T)) -> ^T
{
	return mem.ptr_offset(cast(^T)handle.table.data, cast(int)handle.id - 1);
}

handle_get_raw :: proc(handle: Raw_Handle, type_size: int) -> rawptr
{
	return table_get_raw(handle.raw_table, handle, type_size);
}

table_print :: proc(table: ^$A/Table($T))
{
	log.info("Table {");
	it := table_iterator(table);
	for element in table_iterate(&it)
	{
		log.info(element);
	}

	log.info("}");
}

bit_array_copy :: proc(target: ^Bit_Array, model: ^Bit_Array)
{
	if model.cap > target.cap
	{
		if(target.data != nil)
		{
			mem.free(target.data, target.allocator);
		}
		target.data = cast(^u32)mem.alloc(size_of(u32) * cast(int)model.cap, align_of(u32), target.allocator);
	}
	mem.copy(target.data, model.data, int(model.cap * size_of(u32)));
	target.cap = model.cap;
}

table_copy :: proc(target: ^$A/Table($T), model: ^Table(T))
{
	if model.allocation.cap > target.allocation.cap
	{
		mem.free(target.data, target.allocator);
		mem.free(target.allocator.data, target.allocator);
		target.data = cast(^T)mem.alloc(size_of(T) * cast(int)model.allocation.cap * 32, align_of(T), target.allocator);
		target.allocation.data = cast(^u32)mem.alloc(size_of(u32) * cast(int)model.allocation.cap, align_of(u32), target.allocator);
		target.allocation.cap = model.allocation.cap;
	}
	mem.copy(target.allocation.data, model.allocation.data, int(model.allocation.cap * size_of(u32)));
	mem.copy(target.data, model.data, int(model.allocation.cap * 32 * size_of(T)));
}