package render

import "../container"
import "../geometry"

vec2 :: [2]f32;
Color :: [4]f32;

Render_State :: struct
{
    shader: u32,

    camPosZoomAttrib: i32,
    screenSizeAttrib: i32,

    vao: u32,
    vbo: u32,
    elementBuffer: u32,
}

Color_Vertex_Data :: struct
{
    pos: vec2,
    color: Color
}

Camera :: struct
{
    pos: vec2,
    zoom: f32,
}

Render_Buffer :: struct(T: typeid)
{
    vertex: [dynamic]T,
    index: [dynamic]u32,
}

Render_System :: struct(T: typeid)
{
    screen_size: vec2,
    using buffer: Render_Buffer(T),
    render_state: Render_State,
}

Color_Render_Buffer :: Render_Buffer(Color_Vertex_Data);
Color_Render_System :: Render_System(Color_Vertex_Data);

Texture :: struct
{
    path: string,
    texture_id: u32,
    size: [2]int,
}

Sprite_Handle :: container.Handle(Sprite);
Texture_Handle :: container.Handle(Texture);

Sprite_Data :: struct
{
    anchor: [2]f32,
    clip: geometry.Rect,
}

Sprite :: struct
{
    texture: Texture_Handle,
    id: string,
    using data: Sprite_Data,
}

Sprite_Vertex_Data :: struct
{
    pos: vec2,
    uv: vec2,
    color: Color
}

Sprite_Render_Buffer :: Render_Buffer(Sprite_Vertex_Data);
Sprite_Render_System :: Render_System(Sprite_Vertex_Data);