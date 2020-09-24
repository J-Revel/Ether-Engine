package util

import "core:mem"
import "core:runtime"
import "core:log"

Bit_Array :: struct
{
	data: ^u32,
	cap: int // u32 slots count
}

bit_array_init :: proc(a: ^Bit_Array, cap: int, allocator := context.allocator)
{
	a.data = cast(^u32)mem.alloc(size_of(u32) * cap, align_of(u32), allocator);
	a.cap = cap;
}

bit_array_set :: proc(array: ^Bit_Array, bit: uint, value: bool)
{
	s := transmute([]u32) mem.Raw_Slice{array.data, array.cap};
	array_index := bit / 32;
	bit_index := bit % 32;
	if value do s[array_index] |= 1 << bit_index;
	else do s[array_index] &= ~(1 << bit_index); 
}

bit_array_get :: proc(array: ^Bit_Array, bit: uint) -> bool
{
	s := transmute([]u32) mem.Raw_Slice{array.data, array.cap};
	array_index := bit / 32;
	bit_index := bit % 32;
	return (s[array_index] & 1 << bit_index) > 0;
}

bit_array_allocate :: proc(array: ^Bit_Array) -> (u32, bool)
{
	s := transmute([]u32) mem.Raw_Slice{array.data, array.cap};
	for i in 0..<cast(u32)array.cap * 32
	{
		array_index : u32 = i / 32;
		bit_index : u32 = i % 32;
		bit_flag : u32 = 1 << bit_index;
		if (s[cast(int)array_index] & bit_flag) == 0
		{
			s[array_index] |= bit_flag;
			log.info(s[array_index]);
			return i, true;
		}
	}
	return 0, false;
}


Table :: struct(Value_Type: typeid, Index_Type: typeid)
{
	data: ^T,
	using allocation: Bit_Array,

	allocator: mem.allocator,
}

table_init_none :: proc(a: ^$A/Table, allocator:= context.allocator)
{
	table_init_len_cap(a, 0, 32, allocator);
}

table_init_len_cap :: proc(a: ^$A/Table($V, $I), cap: int, allocator := context.allocator)
{
	a.allocator = allocator;

	a.data = (^T)(mem.alloc(sizeof(T) * cap, align_of(T), allocator));
	bit_array_init(&a.allocation, (cap + 31) / 32, allocator);
}

table_add :: proc(array: ^$A/Table($V, $I), value: V) -> (I, bool)
{
	s := transmute([]u32) mem.Raw_Slice{array.data, array.cap};
	index, ok := bit_array_allocate(array);
	if ok
	{
		s[index] = value;
	}
	return ok;


}

table_init :: proc{table_init_none, table_init_len_cap};

table_delete :: proc(a: $A/Table)
{
	mem.free(a.data, a.allocator);
}