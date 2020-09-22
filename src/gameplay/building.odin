package gameplay

import "src:render"
import l "core:log"
import "core:math"
import "core:math/linalg"

Grounded_Hitbox :: struct
{
    planet: ^Planet,
    size: vec2,
    angle: f32
}

Building_Render_Data :: struct
{
    render_size: vec2,
    color: [4]f32,
}

Building :: struct
{
    using hitbox: Grounded_Hitbox,
    render_data: ^Building_Render_Data,
}

Loading_Building :: struct
{
    using building: ^Building,
    energy: f32,
}

building_render_types := [5]Building_Render_Data
{
    {
        vec2{10, 10}, {1, 0, 0, 1}
    },
    {
        vec2{20, 30}, {1, 1, 0, 1}
    },
    {
        vec2{30, 30}, {1, 0, 1, 1}
    },
    {
        vec2{40, 10}, {0, 1, 0, 1}
    },
    {
        vec2{50, 70}, {0, 1, 1, 1}
    }
};

render_building :: proc(using building: ^Building, renderBuffer: ^render.RenderBuffer)
{
    pos := surface_point(planet, angle);
    surfaceTangent := surface_tangent(planet, angle);
    surfaceNormal := vec2 {surfaceTangent.y, -surfaceTangent.x};

    vertex: []render.VertexData = {
        render.VertexData{pos - surfaceTangent * render_data.render_size.x / 2, render_data.color}, 
        render.VertexData{pos - surfaceTangent * render_data.render_size.x / 2 + surfaceNormal * render_data.render_size.y, render_data.color},
        render.VertexData{pos + surfaceTangent * render_data.render_size.x / 2 + surfaceNormal * render_data.render_size.y, render_data.color},
        render.VertexData{pos + surfaceTangent * render_data.render_size.x / 2, render_data.color}
    };
    indices := []u32{0, 1, 2, 0, 2, 3};
    render.push_mesh_data(renderBuffer, vertex, indices);
}

to_regular_hitbox :: proc(using hitbox: Grounded_Hitbox) -> Bounding_Box
{
    ground_center := surface_point(planet, angle);

    right := surface_tangent(planet, angle);
    up := [2]f32{right.y, -right.x};
    return Bounding_Box{ground_center + up * size.y / 2, angle, size};
}

is_inside_g_bb :: proc(using hitbox: ^Grounded_Hitbox, pos: [2]f32) -> bool
{
    using math;
    ground_center := surface_point(planet, angle);

    right := surface_tangent(planet, angle);
    up := [2]f32{right.y, -right.x};

    dir := pos - ground_center;
    x := linalg.dot(right, dir);
    y := linalg.dot(up, dir);

    return x > -size.x / 2 && x < size.x / 2 && y > 0 && y < size.y;

}