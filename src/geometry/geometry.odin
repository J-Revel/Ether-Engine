package geometry

import "intrinsics"
import "core:math"

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