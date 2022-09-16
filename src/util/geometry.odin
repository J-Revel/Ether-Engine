package util 

import "core:intrinsics"
import "core:math"
import "core:math/linalg"

Rect :: struct($T: typeid)
{
	pos, size: [2]T,
}

rotate :: proc(v: $V/[$N]$E, angle: f32) -> V
{
	c := math.cos(angle);
	s := math.sin(angle);
	return V{c * v.x - s * v.y, s * v.x + c * v.y};
}

vector_angle :: proc(v : [2]$E) -> E
{
	return math.atan2_f32(v.y, v.x);
}

is_in_rect :: proc(rect: Rect($T), pos: [2]T) -> bool
{
    return pos.x >= rect.pos.x && 
		pos.x < rect.pos.x + rect.size.x &&
		pos.y >= rect.pos.y &&
		pos.y < rect.pos.y + rect.size.y;
}

get_sub_rect :: proc(parent: Rect($T), sub_rect: Rect(T)) -> Rect(T)
{
	return { parent.pos + sub_rect.pos * parent.size, parent.size * sub_rect.size };
}

get_relative_pos :: proc(rect: Rect($T), pos: [2]T) -> [2]T
{
	return (pos - rect.pos) / rect.size;
}

relative_to_world :: proc(rect: Rect($T), pos: [2]T) -> [2]T
{
	return rect.pos + pos * rect.size;
}

append_and_get :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> ^E 
{
    if array == nil do return nil;

    append(array, E{});

    return &array[len(array)-1];
}

append_and_get_index :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> int 
{
    if array == nil do return -1;

    append(array, E{});

    return len(array)-1;
}

rect_vsplit :: proc(rect: Rect($T), top_size: T) -> (out_top_rect: Rect(T), out_bottom_rect: Rect(T)) {
	out_top_rect = Rect(T){rect.pos, [2]T{rect.size.x, top_size} }
	offset := [2]T{0, top_size}
	out_bottom_rect = Rect(T){rect.pos + offset, rect.size - offset}
	return
}

rect_padding :: proc(rect: Rect($T), padding: T) -> Rect(T) {
	return Rect(T){
		rect.pos + [2]T{padding, padding},
		rect.size - [2]T{padding * 2, padding * 2},
	}
}

union_bounding_rect :: proc(A: Rect($T), B: Rect(T)) -> Rect(T) {
	top_left := [2]T{math.min(A.pos.x, B.pos.x), math.min(A.pos.y, B.pos.y)}
	bottom_right := [2]T{math.max(A.pos.x + A.size.x, B.pos.x + B.size.x), math.max(A.pos.y + A.size.y, B.pos.y + B.size.y)}
	return Rect(T) {
		pos = top_left,
		size = bottom_right - top_left,
	}
}

round_rect_to_i32 :: proc(rect: Rect(f32)) -> Rect(i32) {
	top_left := linalg.to_i32(rect.pos)
	bottom_right := linalg.to_i32([2]f32{math.ceil(rect.pos.x + rect.size.x), math.ceil(rect.pos.y + rect.size.y)})
	return Rect(i32) {
		top_left,
		bottom_right - top_left,
	}
}