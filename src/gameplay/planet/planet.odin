package planet;
import render "../../render";
import math "core:math"
import geometry "core:math/linalg"

vec2 :: [2]f32;

PlanetShapeHarmonic :: struct
{
    f, offset: f32
}

PlanetConfig :: struct
{
    r: f32,
    harmonics: [dynamic]PlanetShapeHarmonic
}

radius :: proc(meanRadius: f32, angle: f32) -> f32
{
    return meanRadius + meanRadius / 30 * math.cos(angle * 10) + meanRadius / 10 * math.sin(angle * 3) + meanRadius / 50 * math.cos( 5 + angle * 12);
}

generatePlanet :: proc(renderBuffer: ^render.RenderBuffer, planet: ^PlanetConfig, subdivisions: u32)
{
    vertex: []render.VertexData = make([]render.VertexData, subdivisions + 1);
    defer delete(vertex);
    index: []u32 = make([]u32, subdivisions * 3);
    for i : u32 = 0; i<subdivisions; i += 1
    {
        angle := (cast(f32)i * 2) * math.PI / (cast(f32)subdivisions);
        
        vertex[i] = render.VertexData{planetSurfacePoint(planet, angle), {0, 0, 0, 1}};
    }
    vertex[subdivisions] = render.VertexData{{0, 0}, {1, 1, 1, 1}};
    for i : u32 = 0; i<subdivisions; i+=1
    {
        index[i * 3] = subdivisions;
        index[i * 3 + 1] = i;
        index[i * 3 + 2] = (i + 1) % subdivisions;
    }
    render.pushMeshData(renderBuffer, vertex, index);
}

planetSurfacePoint :: proc(planet: ^PlanetConfig, angle: f32) -> vec2
{
    r := planet.r;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * math.sin(harmonic.offset + angle * cast(f32)hIndex);
    }
    return vec2{r * math.cos(angle), r * math.sin(angle)};
}

planetSurfaceNormal :: proc(planet: ^PlanetConfig, angle: f32) -> vec2
{
    using math;
    using geometry;
    dr:f32 = 0;
    r := planet.r;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * sin(harmonic.offset + angle * cast(f32)hIndex);
        dr += harmonic.f * planet.r * cast(f32)hIndex * cos(harmonic.offset + angle * cast(f32)hIndex);
    }
    return vector_normalize(vec2 {
        dr * cos(angle) - r * sin(angle),
        dr * sin(angle) + r * cos(angle)
    });
}