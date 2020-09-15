package entity

import "../../render"
import "../planet"

import "../../geometry"

import "core:log"

Building :: struct
{
    planet: ^planet.Instance,
    size: vec2,
    angle: f32,
}

renderBuilding :: proc(building: ^Building, renderBuffer: ^render.RenderBuffer)
{
    pos := planet.surfacePoint(building.planet, building.angle);
    surfaceTangent := planet.surfaceNormal(building.planet, building.angle) * 50;
    surfaceNormal := vec2 {surfaceTangent.y, -surfaceTangent.x};

    vertex: []render.VertexData = {
        render.VertexData{pos - surfaceTangent / 2, {1, 1, 1, 1}}, 
        render.VertexData{pos - surfaceTangent / 2 + surfaceNormal, {1, 1, 1, 1}},
        render.VertexData{pos + surfaceTangent / 2 + surfaceNormal, {1, 1, 1, 1}},
        render.VertexData{pos + surfaceTangent / 2, {1, 1, 1, 1}}
    };
    indices := []u32{0, 1, 2, 0, 2, 3};
    render.pushMeshData(renderBuffer, vertex, indices);
}