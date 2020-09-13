package planet;
import render "../../render";
import math "core:math"
import geometry "core:math/linalg"

vec2 :: [2]f32;

ShapeHarmonic :: struct
{
    f, offset: f32
}

Config :: struct
{
    r: f32,
    harmonics: [dynamic]ShapeHarmonic
}

Instance :: struct
{
    pos: vec2,
    using config: Config
}

radius :: proc(meanRadius: f32, angle: f32) -> f32
{
    return meanRadius + meanRadius / 30 * math.cos(angle * 10) + meanRadius / 10 * math.sin(angle * 3) + meanRadius / 50 * math.cos( 5 + angle * 12);
}

render :: proc(renderBuffer: ^render.RenderBuffer, planet: ^Instance, subdivisions: u32)
{
    vertex: []render.VertexData = make([]render.VertexData, subdivisions + 1);
    defer delete(vertex);
    index: []u32 = make([]u32, subdivisions * 3);
    for i : u32 = 0; i<subdivisions; i += 1
    {
        angle := (cast(f32)i * 2) * math.PI / (cast(f32)subdivisions);
        
        vertex[i] = render.VertexData{planetSurfacePoint(planet, angle) + planet.pos, {0, 0, 0, 1}};
    }
    vertex[subdivisions] = render.VertexData{planet.pos, {1, 1, 1, 1}};
    for i : u32 = 0; i<subdivisions; i+=1
    {
        index[i * 3] = subdivisions;
        index[i * 3 + 1] = i;
        index[i * 3 + 2] = (i + 1) % subdivisions;
    }
    render.pushMeshData(renderBuffer, vertex, index);
}

planetSurfacePoint :: proc(planet: ^Config, angle: f32) -> vec2
{
    r := planet.r;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * math.sin(harmonic.offset + angle * cast(f32)(hIndex + 1));
    }
    return vec2{r * math.cos(angle), r * math.sin(angle)};
}

planetSurfaceNormal :: proc(planet: ^Config, angle: f32) -> vec2
{
    using math;
    using geometry;
    dr:f32 = 0;
    r := planet.r;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * sin(harmonic.offset + angle * cast(f32)(hIndex + 1));
        dr += harmonic.f * planet.r * cast(f32)hIndex * cos(harmonic.offset + angle * cast(f32)(hIndex + 1));
    }
    return vector_normalize(vec2 {
        dr * cos(angle) - r * sin(angle),
        dr * sin(angle) + r * cos(angle)
    });
}