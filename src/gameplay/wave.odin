package gameplay;

import l "core:log"
import "../render"
import "core:math"
import "core:mem"
import "../util/container"

Arc :: struct
{
	radius: f32,
	angle: f32,
	angular_size: f32
}

Wave_Arc :: struct
{
	energy: f32,
	center: [2]f32,
	using arc: Arc,
}

points_along_arc :: proc(arc: ^Wave_Arc, step_size: f32, allocator := context.temp_allocator) -> []vec2
{
	using math;
	length := arc.angular_size * arc.radius;
	step_count := cast(int)(length / step_size) + 1;
	step_size := arc.angular_size / cast(f32)step_count;
	result := make([]vec2, step_count + 1);
	for i := 0; i <= step_count; i += 1
	{
		angle := arc.angle + cast(f32)i * step_size;
		result[i] = arc.center + vec2{cos(angle), sin(angle)} * arc.radius;
	}
	return result;
}

arc_collision_split_planet :: proc(arc: Wave_Arc, step_size: f32, planet: ^Planet, out_arcs: ^container.Table(Wave_Arc))
{
	using math;
	if(arc.radius == 0)
	{
		container.table_add(out_arcs, arc);
		return;
	}
	length := arc.angular_size * arc.radius;
	step_count := cast(int)(length / step_size) + 1;
	step_size := arc.angular_size / cast(f32)step_count;
	last_point_inside: bool = false;
	last_added_arc := arc;
	angle := arc.angle;
	radius := arc.radius;

	split_arc := arc;

	for i := 0; i<=step_count; i+=1
	{
		step_angle := angle + cast(f32)i * step_size;
		point := arc.center + vec2{cos(step_angle), sin(step_angle)} * arc.radius;
		if(is_inside_planet(planet, point, step_size) != last_point_inside)
		{
			if(last_point_inside)
			{
				split_arc.angle = step_angle - step_size * 95 / 100;
			}
			else
			{
				split_arc.angular_size = step_angle - split_arc.angle - step_size * 5 / 100;
				split_arc.energy = arc.energy * split_arc.angular_size / length * radius;
				if step_angle != split_arc.angle
				{
					container.table_add(out_arcs, split_arc);
				}
			}
			last_point_inside = !last_point_inside;
		}
	}
	if !last_point_inside
	{
		split_arc.angular_size = angle + arc.angular_size - split_arc.angle;
		split_arc.energy = arc.energy * split_arc.angular_size / length * radius;
		container.table_add(out_arcs, split_arc);
	}
}

arc_collision_split_hitbox :: proc(arc: Wave_Arc, step_size: f32, hitbox: ^Grounded_Hitbox, out_arcs: ^[dynamic]Wave_Arc) -> f32
{
	using math;
	result: f32 = 0;
	if(arc.radius == 0)
	{
		append(out_arcs, arc);
		return result;
	}
	length := arc.angular_size * arc.radius;
	step_count := cast(int)(length / step_size) + 1;
	step_size := arc.angular_size / cast(f32)step_count;
	last_point_inside: bool = false;
	last_added_arc := arc;
	angle := arc.angle;
	radius := arc.radius;

	split_arc := arc;

	for i := 0; i<=step_count; i+=1
	{
		step_angle := angle + cast(f32)i * step_size;
		point := arc.center + vec2{cos(step_angle), sin(step_angle)} * arc.radius;
		if is_inside_g_bb(hitbox, point) != last_point_inside
		{
			if(last_point_inside)
			{
				split_arc.angle = step_angle - step_size * 95 / 100;
				result += arc.energy * step_size * 5 / 100 / length;
			}
			else
			{
				result += arc.energy * step_size * 5 / 100 / length;
				split_arc.angular_size = step_angle - split_arc.angle - step_size * 5 / 100;
				split_arc.energy = arc.energy * split_arc.angular_size / length * radius;
				if(step_angle != split_arc.angle)
				{
					append(out_arcs, split_arc);
				}
			}
			last_point_inside = !last_point_inside;
		}
		else if last_point_inside do result += arc.energy * step_size / length;
	}
	if !last_point_inside
	{
		split_arc.angular_size = angle + arc.angular_size - split_arc.angle;
		split_arc.energy = arc.energy * split_arc.angular_size / length * radius;
		append(out_arcs, split_arc);
	}

	return result;
}

update_wave_collision_planet :: proc(arcs: ^container.Table(Wave_Arc), step_size: f32, max_radius: f32, planet: ^Planet)
{
	new_arcs : container.Table(Wave_Arc);
	container.table_init(&new_arcs, arcs.allocation.cap, context.temp_allocator);
	arcs_it := container.table_iterator(arcs);
	for arc in container.table_iterate(&arcs_it)
	{
		if(arc.radius < max_radius) do
			arc_collision_split_planet(arc^, step_size, planet, &new_arcs);
	}
	container.table_copy(arcs, &new_arcs);
}

update_wave_collision_hitbox :: proc(arcs: ^[dynamic]Wave_Arc, step_size: f32, max_radius: f32, hitbox: ^Grounded_Hitbox) -> f32
{
	new_arcs := make([dynamic]Wave_Arc, 0, 10, context.temp_allocator);
	result: f32 = 0;
	for arc in arcs
	{
		if(arc.radius < max_radius) do
			result += arc_collision_split_hitbox(arc, step_size, hitbox, &new_arcs);
	}
	resize(arcs, len(new_arcs));
	copy(arcs[:], new_arcs[:]);
	return result;
}

update_wave_collision :: proc { update_wave_collision_planet, update_wave_collision_hitbox };

render_wave :: proc(arcs: ^container.Table(Wave_Arc), step_size : f32, thickness: f32, color: [4]f32, render_system: ^render.Render_System)
{
	vertex : [dynamic]render.VertexData;
	index : [dynamic]u32;

	arc_it := container.table_iterator(arcs);
	for arc in container.table_iterate(&arc_it)
	{
		length := arc.angular_size * arc.radius;
		step_count := cast(int)(length / step_size) + 1;
		if(step_count > 100) do
			step_count = 100;
		step_size := arc.angular_size / cast(f32)step_count;
		
		for i := 0; i<step_count + 1; i += 1
		{
			vertex_angle := arc.angle + step_size * cast(f32)i;
			v :[2]f32 = arc.center + (arc.radius - thickness / 2) * [2]f32{math.cos(vertex_angle), math.sin(vertex_angle)};
			append(&vertex, render.VertexData{v, {0, 0, 0, 0}});
			v = arc.center + (arc.radius + thickness / 2) * [2]f32{math.cos(vertex_angle), math.sin(vertex_angle)};
			append(&vertex, render.VertexData{v, color});	
		}

		for i : u32 = 1; i < cast(u32)step_count; i += 1
		{
			append(&index, i * 2 - 2);
			append(&index, i * 2 - 1);
			append(&index, i * 2);
			append(&index, i * 2 - 1);
			append(&index, i * 2);
			append(&index, i * 2 + 1);
		}
		append(&index, (cast(u32)step_count) * 2 - 2);
		append(&index, (cast(u32)step_count) * 2 - 1);
		append(&index, (cast(u32)step_count) * 2);
		append(&index, (cast(u32)step_count) * 2 - 1);
		append(&index, (cast(u32)step_count) * 2);
		append(&index, (cast(u32)step_count) * 2 + 1);
		render.push_mesh_data(render_system, vertex[:], index[:]);
		clear(&vertex);
		clear(&index);
	}
}