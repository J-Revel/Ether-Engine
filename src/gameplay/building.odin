package gameplay

import "src:render"
import "core:log"

Building_Render_Data :: struct
{
    render_size: vec2,
    color: [4]f32,
}

Building :: struct
{
    planet: ^Planet,
    size: vec2,
    angle: f32,
    render_data: ^Building_Render_Data,
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
    pos := surfacePoint(planet, angle);
    surfaceTangent := surfaceNormal(planet, angle);
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

Loading_Building :: struct
{
    value: f32,
    max: f32,
}

update_loading_buildings :: proc(buildings: []Loading_Building)
{

}