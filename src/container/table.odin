package table

import "core:mem"
import "core:runtime"
import "core:log"
import "core:reflect"

bit_array_set :: proc(bit_array: ^Bit_Array, bit: uint, value: bool)
{
	array_index := bit / 32;
	bit_index := bit % 32;
	if value do bit_array[array_index] |= 1 << bit_index;
	else do bit_array[array_index] &= ~(1 << bit_index); 
}

bit_array_get :: proc(bit_array: ^Bit_Array, bit: int) -> bool
{
	array_index := bit / 32;
	bit_index := bit % 32;
	value := bit_array[array_index];
	return (value & (1 << uint(bit_index))) > 0;
}

bit_array_allocate :: proc(bit_array: ^Bit_Array) -> (int, bool)
{
	for i in 0..<cast(uint)len(bit_array) * 32
	{
		array_index := i / 32;
		bit_index := i % 32;
		bit_flag : u32 = 1 << bit_index;
		value := &bit_array[array_index];
		if (value^ & bit_flag) == 0
		{
			value^ |= bit_flag;
			return int(i), true;
		}
	}
	return 0, false;
}

table_init :: proc{table_init_none, table_init_cap};

table_init_none :: proc(a: ^$A/Table, allocator:= context.allocator)
{
	table_init_cap(a, 100, allocator);
}

table_init_cap :: proc(a: ^$A/Table($V), cap: uint, allocator := context.allocator)
{
	a.allocator = allocator;

	a.data = (mem.alloc(size_of(V) * int(cap), align_of(V), allocator));
	a.allocation = make(Bit_Array, (cap + 31) / 32, allocator);
}

table_add :: proc(table: ^$A/Table($T), value: T) -> (Handle(T), bool)
{
	index, ok := bit_array_allocate(&table.allocation);
	if ok
	{
		mem.ptr_offset(cast(^T)table.data, index)^ = value;
	}
	return Handle(T){index + 1, table}, ok;
}

ptr_offset :: inline proc(ptr: uintptr, n: int, type_size: int) -> uintptr {
	new := int(ptr) + type_size * n;
	return uintptr(new);
}

table_add_raw :: proc(table: ^Raw_Table, value: any, type_size: int) -> (Raw_Handle, bool)
{
	index, ok := bit_array_allocate(table.allocation);
	if ok
	{
		mem.copy(rawptr(ptr_offset(uintptr(table.data), int(index), type_size)), value.data, type_size);
	}
	return Raw_Handle{index + 1, table}, ok;
}

// like table_add_raw but does not set the value yed
table_allocate_raw :: proc(table: ^Raw_Table) -> (Raw_Handle, bool)
{
	index, ok := bit_array_allocate(table.allocation);
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
	cursor := 0;
	for ;cursor < len(table.allocation) * 32 && !bit_array_get(&table.allocation, cursor); cursor += 1 {}
	return Table_Iterator(T){table, cursor};
}

iterate :: proc{ table_iterate };

table_iterate :: proc(it: ^$A/Table_Iterator($T)) -> (value: ^T, id: Handle(T), ok: bool)
{
	if it.cursor < len(it.table.allocation) * 32
	{
		ok = true;
	}
	id = Handle(T){it.cursor + 1, it.table};
	value = table_get(it.table, id);
	it.cursor += 1;
	for it.cursor < len(it.table.allocation) * 32 && !bit_array_get(&it.table.allocation, it.cursor)
	{
		it.cursor += 1;
	}
	return;
}

table_get :: proc(table: ^$A/Table($T), index: Handle(T)) -> ^T
{
	return mem.ptr_offset(cast(^T)table.data, cast(int)index.id - 1);
}

handle_get_raw :: proc(handle: Raw_Handle) -> rawptr
{
	table := handle.raw_table;
	type_size := reflect.size_of_typeid(table.type_id);
	return rawptr(uintptr(int(uintptr(table.data)) + type_size * int(handle.id - 1)));
}

handle_get :: proc(handle: $A/Handle($T)) -> ^T
{
	return mem.ptr_offset(cast(^T)handle.table.data, cast(int)handle.id - 1);
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

raw_table_copy :: proc(target: ^Raw_Table, model: ^Raw_Table)
{

}

db_get_table :: proc(db: Database, name: string) -> (Raw_Table, int, bool)
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

to_raw_table :: proc(table: ^Table($T)) -> Raw_Table
{
	return Raw_Table{table.data, &table.allocation, table.allocator, typeid_of(T)};
}