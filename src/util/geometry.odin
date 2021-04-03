package util 

import "intrinsics"
import "core:math"

Rect :: struct
{
	pos, size: [2]f32
}

rotate :: proc(v: $V/[$N]$E, angle: f32) -> V where intrinsics.type_is_numeric(E) 
{
	c := math.cos(angle);
	s := math.sin(angle);
	return V{c * v.x - s * v.y, s * v.x + c * v.y};
}

vector_angle :: proc(v : [2]$E) -> E where intrinsics.type_is_numeric(E)
{
	return math.atan2_f32(v.y, v.x);
}

is_in_rect :: proc(rect: Rect, pos: [2]f32) -> bool
{
    return pos.x >= rect.pos.x && pos.x < rect.pos.x + rect.size.x
        && pos.y >= rect.pos.y && pos.y < rect.pos.y + rect.size.y;
}

get_sub_rect :: proc(parent: Rect, sub_rect: Rect) -> Rect
{
	return { parent.pos + sub_rect.pos * parent.size, parent.size * sub_rect.size };
}

get_relative_pos :: proc(rect: Rect, pos: [2]f32) -> [2]f32
{
	return (pos - rect.pos) / rect.size;
}

relative_to_world :: proc(rect: Rect, pos: [2]f32) -> [2]f32
{
	return rect.pos + pos * rect.size;
}

append_and_get :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> ^E #no_bounds_check
{
    if array == nil do return nil;

    n := len(array);
    resize(array, n+1);

    return len(array) == n+1 ? &array[len(array)-1] : nil;
}

append_and_get_index :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> int #no_bounds_check
{
    if array == nil do return -1;

    n := len(array);
    resize(array, n+1);

    return len(array) == n+1 ? len(array)-1 : -1;
}
