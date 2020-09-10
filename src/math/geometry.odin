package math

v2 :: distinct [2] f32;

v4 :: distinct [4] f32;

dot :: proc(a: v2, b: v2) -> f32
{
    return a.x * b.x + a.y * b.y;
}

cross :: proc(a: v2, b: v2) -> f32
{
    return a.x * b.y - a.y * b.x;
}
