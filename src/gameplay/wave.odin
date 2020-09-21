package gameplay;

import l "core:log"
import "src:render"
import "core:math"
import "core:mem"

WaveId :: distinct u32;

Wave :: struct
{
	arcs: [dynamic]Wave_Arc,
	duration: f32,
}

Wave_Arc :: struct
{
	id : WaveId,
	center: [2]f32,
	radius: f32,
	angle: f32,
	angular_size: f32

}

arc_collision_split :: proc(arc: Wave_Arc, step_size: f32, planet: ^Planet, out_arcs: ^[dynamic]Wave_Arc)
{
	using math;
	if(arc.radius == 0)
	{
		append(out_arcs, arc);
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
				if(step_angle != split_arc.angle)
				{
					append(out_arcs, split_arc);
				}
			}
			last_point_inside = !last_point_inside;
		}
	}
	if !last_point_inside
	{
		split_arc.angular_size = angle + arc.angular_size - split_arc.angle;
		append(out_arcs, split_arc);
	}
}

update_wave_collision :: proc(wave: ^Wave, step_size: f32, max_radius: f32, planet: ^Planet)
{
	new_arcs := make([dynamic]Wave_Arc, 0, 10, context.temp_allocator);
	for arc in wave.arcs
	{
		if(arc.radius < max_radius) do
			arc_collision_split(arc, step_size, planet, &new_arcs);
	}
	resize(&wave.arcs, len(new_arcs));
	copy(wave.arcs[:], new_arcs[:]);
}

render_wave :: proc(wave: ^Wave, step_size : f32, thickness: f32, color: [4]f32, render_system: ^render.Render_System)
{
	vertex : [dynamic]render.VertexData;
	index : [dynamic]u32;

	for arc in &wave.arcs
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