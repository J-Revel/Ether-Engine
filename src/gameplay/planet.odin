package gameplay
import math "core:math"
import linalg "core:math/linalg"
import console "core:log"
import "core:math/rand"
import "../render"

vec2 :: [2]f32;

Planet_Harmonic :: struct
{
    f, offset: f32
}

Config :: struct
{
    r: f32,
    harmonics: [dynamic]Planet_Harmonic
}

Planet :: struct
{
    pos: vec2,
    using config: Config
}

radius :: proc(meanRadius: f32, angle: f32) -> f32
{
    return meanRadius + meanRadius / 30 * math.cos(angle * 10) + meanRadius / 10 * math.sin(angle * 3) + meanRadius / 50 * math.cos( 5 + angle * 12);
}

render_planet :: proc(renderBuffer: ^render.Render_Buffer(render.Color_Vertex_Data), planet: ^Planet, subdivisions: u32)
{
    vertex: []render.Color_Vertex_Data = make([]render.Color_Vertex_Data, subdivisions + 1);
    defer delete(vertex);
    index: []u32 = make([]u32, subdivisions * 3);
    defer delete(index);
    for i : u32 = 0; i<subdivisions; i += 1
    {
        angle := (cast(f32)i * 2) * math.PI / (cast(f32)subdivisions);
        
        vertex[i] = render.Color_Vertex_Data{surface_point(planet, angle), {0, 0, 0, 1}};
    }
    vertex[subdivisions] = render.Color_Vertex_Data{planet.pos, {1, 1, 1, 1}};
    for i : u32 = 0; i<subdivisions; i+=1
    {
        index[i * 3] = subdivisions;
        index[i * 3 + 1] = i;
        index[i * 3 + 2] = (i + 1) % subdivisions;
    }
    render.push_mesh_data(renderBuffer, vertex, index);
}

r :: proc(planet: ^Planet, angle: f32) -> f32
{
    r := planet.r;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * math.sin(harmonic.offset + angle * cast(f32)(hIndex + 1));
    }
    return r;
}

rdr :: proc(planet: ^Config, angle: f32) -> (f32, f32)
{
    r := planet.r;
    dr : f32 = 0;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * math.sin(harmonic.offset + angle * cast(f32)(hIndex + 1));
        dr += harmonic.f * planet.r * cast(f32)(hIndex+1) * math.cos(harmonic.offset + angle * cast(f32)(hIndex + 1));
    }
    return r, dr;
}

surface_point :: proc(planet: ^Planet, angle: f32) -> vec2
{
    r := r(planet, angle);
    return planet.pos + vec2{r * math.cos(angle), r * math.sin(angle)};
}

surface_tangent :: proc(planet: ^Config, angle: f32) -> vec2
{
    r, dr := rdr(planet, angle);
    cosa := math.cos(angle);
    sina := math.sin(angle);

    return linalg.vector_normalize(vec2 {
        dr * cosa - r * sina,
        dr * sina + r * cosa
    });
}

surface_axes :: proc(planet: ^Planet, angle: f32) -> (origin: vec2, up: vec2, right: vec2)
{
    origin = surface_point(planet, angle);
    right = surface_tangent(planet, angle);
    up = [2]f32{right.y, -right.x};
    return;
}

surface_normal :: proc(planet: ^Config, angle: f32) -> vec2
{
    r, dr := rdr(planet, angle);
    cosa := math.cos(angle);
    sina := math.sin(angle);

    return linalg.vector_normalize(vec2 {
        dr * sina + r * cosa,
        -dr * cosa - r * sina
    });
}

@private
point_slope_test :: proc(planet: ^Planet, angle: f32, M: vec2) -> f32
{
    using math;
    MO := planet.pos - M;
    r, dr := rdr(planet, angle);
    cosa := cos(angle);
    sina := sin(angle);
    return 2 * dr *(MO.x * cosa + MO.y * sina) + 2 * r * (MO.y * cosa - MO.x * sina) + 2 * r * dr;
}

closest_surface_angle :: proc(planet: ^Planet, M: vec2, prcSteps: int) -> f32
{
    using math;
    OM := M - planet.pos;
    angle := math.atan2_f32(OM.y, OM.x);
    delta : f32 = PI / 500;
    slopeValue := point_slope_test(planet, angle, M);
    lastSlopeValue := slopeValue;
    steps:=0;
    for steps=0; steps < prcSteps && slopeValue * lastSlopeValue > 0; steps += 1
    {
        stepCount := cast(f32) prcSteps;
        stepRatio := cast(f32)steps / stepCount;
        if slopeValue < 0 do angle += delta * cast(f32)(1 - stepRatio); else do angle -= delta * cast(f32)(1 - stepRatio);
        lastSlopeValue = slopeValue;
        slopeValue = point_slope_test(planet, angle, M);
    }
    return angle;
}

is_inside_planet :: proc(planet: ^Planet, M: vec2, depth: f32 = 0) -> bool
{
    using math;
    OM := M - planet.pos;
    angle := math.atan2_f32(OM.y, OM.x);
    _r := r(planet, angle) - depth;
    return OM.x * OM.x + OM.y * OM.y < _r * _r;
}

generate :: proc(result: ^Config, r: f32, harmonicCount: int) 
{
    result.r = r;
    for i := 0; i < harmonicCount; i+=1
    {
        harmonic := Planet_Harmonic{0.2, 1};
        harmonic.f = rand.float32() / cast(f32) (i * 2 + 1) / 3;
        harmonic.offset = rand.float32() * 2 * math.PI;
        append(&result.harmonics, harmonic);
    }
}