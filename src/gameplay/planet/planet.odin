package planet;
import render "../../render"
import math "core:math"
import geometry "core:math/linalg"
import console "core:log"

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
    defer delete(index);
    for i : u32 = 0; i<subdivisions; i += 1
    {
        angle := (cast(f32)i * 2) * math.PI / (cast(f32)subdivisions);
        
        vertex[i] = render.VertexData{surfacePoint(planet, angle), {0, 0, 0, 1}};
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

r :: proc(planet: ^Instance, angle: f32) -> f32
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
    using math;
    using geometry;
    r := planet.r;
    dr : f32 = 0;
    for harmonic, hIndex in planet.harmonics
    {
        r += harmonic.f * planet.r * sin(harmonic.offset + angle * cast(f32)(hIndex + 1));
        dr += harmonic.f * planet.r * cast(f32)(hIndex+1) * cos(harmonic.offset + angle * cast(f32)(hIndex + 1));
    }
    return r, dr;
}

surfacePoint :: proc(planet: ^Instance, angle: f32) -> vec2
{
    r := r(planet, angle);
    return planet.pos + vec2{r * math.cos(angle), r * math.sin(angle)};
}

surfaceNormal :: proc(planet: ^Config, angle: f32) -> vec2
{
    using math;
    using geometry;
    r,dr := rdr(planet, angle);
    cosa := cos(angle);
    sina := sin(angle);

    return vector_normalize(vec2 {
        dr * cosa - r * sina,
        dr * sina + r * cosa
    });
}

pointSlopeTest :: proc(planet: ^Instance, angle: f32, M: vec2) -> f32
{
    using math;
    MO := planet.pos - M;
    r, dr := rdr(planet, angle);
    cosa := cos(angle);
    sina := sin(angle);
    return 2 * dr *(MO.x * cosa + MO.y * sina) + 2 * r * (MO.y * cosa - MO.x * sina) + 2 * r * dr;
}

closestSurfaceAngle :: proc(planet: ^Instance, M: vec2, prcSteps: int) -> f32
{
    using math;
    OM := M - planet.pos;
    angle := math.atan2_f32(OM.y, OM.x);
    delta : f32 = PI / 500;
    slopeValue := pointSlopeTest(planet, angle, M);
    lastSlopeValue := slopeValue;
    steps:=0;
    for steps=0; steps < prcSteps && slopeValue * lastSlopeValue > 0; steps += 1
    {
        stepCount := cast(f32) prcSteps;
        stepRatio := cast(f32)steps / stepCount;
        if slopeValue < 0 do angle += delta * cast(f32)(1 - stepRatio); else do angle -= delta * cast(f32)(1 - stepRatio);
        lastSlopeValue = slopeValue;
        slopeValue = pointSlopeTest(planet, angle, M);
    }
    return angle;
}

