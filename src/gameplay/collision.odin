package gameplay

import "core:math";
import "core:sort";
import "core:math/linalg"
import l "core:log"

Bounding_Box :: struct
{
	center: vec2,
	angle: f32,
	size: vec2
}

Circle :: struct
{
	center: vec2,
	radius: f32
}

is_inside_bb :: proc(using bb: ^Bounding_Box, pos: [2]f32) -> bool
{
    using math;

	up :=  vec2{cos(bb.angle), sin(bb.angle)};
	right := vec2{up.y, -up.x};

    dir := pos - bb.center;
    x := linalg.dot(right, dir);
    y := linalg.dot(up, dir);

    return x > -size.x / 2 && x < size.x / 2 && y > -size.y / 2 && y < size.y / 2;
}

collision_hitbox_empty_circle :: proc(hitbox: ^Bounding_Box, circle: ^Circle) -> bool
{
	using math;
	up_dir := vec2{cos(hitbox.angle), sin(hitbox.angle)};
	hitbox_up :=  up_dir * hitbox.size.y / 2;
	hitbox_right := vec2{up_dir.y, -up_dir.x} * hitbox.size.x / 2;

	points := []vec2{
		hitbox.center + hitbox_right + hitbox_up,
		hitbox.center - hitbox_right + hitbox_up,
		hitbox.center + hitbox_right - hitbox_up,
		hitbox.center - hitbox_right - hitbox_up
	};

	min_distance : f32 = 99999999;
	max_distance : f32 = 0;
	for i:= 0; i<4; i += 1
	{
		distance : f32 = linalg.vector_length(circle.center - points[i]);
		min_distance = min(distance, min_distance);
		max_distance = max(distance, max_distance);
	}

	return circle.radius > min_distance && circle.radius < max_distance;
}

collision_bb_arc :: proc(bb: ^Bounding_Box, arc: ^Wave_Arc, step_size: f32) -> bool
{
	circle := Circle{arc.center, arc.radius};
	if collision_hitbox_empty_circle(bb, &circle)
	{
		for point in points_along_arc(arc, step_size)
		{
			if(is_inside_bb(bb, point)) do return true;
		}
	}
	return false;
}