package geometry

import "intrinsics"
import "core:math"
import "../geometry"

Rect :: struct(Type: typeid)
{
	pos, size: [2]Type
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

is_in_rect :: proc(rect: geometry.Rect($T), pos: [2]T) -> bool
{
    return pos.x >= rect.pos.x && pos.x < rect.pos.x + rect.size.x
        && pos.y >= rect.pos.y && pos.y < rect.pos.y + rect.size.y;
}

get_sub_rect :: proc(parent: Rect($T), sub_rect: Rect(T)) -> Rect(T)
{
	return { parent.pos + sub_rect.pos * parent.size, parent.size * sub_rect.size };
}

get_relative_pos :: proc(rect: geometry.Rect(f32), pos: [2]f32) -> [2]f32
{
	return (pos - rect.pos) / rect.size;
}

relative_to_world :: proc(rect: geometry.Rect(f32), pos: [2]f32) -> [2]f32
{
	return rect.pos + pos * rect.size;
}