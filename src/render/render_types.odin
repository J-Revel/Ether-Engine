package render

import "../container"
import "../util"
import "../../libs/freetype"

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
    default_texture: u32,
}

Color_Vertex_Data :: struct
{
    pos: vec2,
    color: Color
}

Viewport :: struct
{
    top_left: [2]int,
    size: [2]int,
}

Camera :: struct
{
    world_pos: vec2,
    zoom: f32,
}

Render_Buffer :: struct(T: typeid)
{
    vertex: [dynamic]T,
    index: [dynamic]u32,
}

Render_System :: struct(T: typeid)
{
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
    clip: util.Rect,
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

Sprite_Render_Pass :: struct
{
    texture: Texture_Handle,
    index_count: int,
}

Sprite_Render_Type :: enum
{
	World,
	UI,
}

Sprite_Render_Buffer :: Render_Buffer(Sprite_Vertex_Data);
Sprite_Render_System :: struct
{
    using render_system: Render_System(Sprite_Vertex_Data),
    passes: [dynamic]Sprite_Render_Pass,
    current_texture: Texture_Handle,
    current_pass_index: int,
	render_type: Sprite_Render_Type,
}

Sprite_Asset :: struct
{
    // Path without the extension (.png = texture path, .meta = sprite list path)
    path: string,
    sprite_id: string,
}

Sprite_Database :: struct
{
    textures: container.Table(Texture),
    sprites: container.Table(Sprite),
}

/*-------------------------
		Text
---------------------------*/


Glyph :: struct
{
	size: [2]int,
	bearing: [2]int,
	advance: [2]int,
	uv_min: [2]f32,
	uv_max: [2]f32,
}

Font :: struct
{
	face: freetype.Face,
	glyphs: map[rune]Glyph,
}

/*-------------------------
		Atlas
---------------------------*/

Atlas :: struct
{
	texture_size: [2]int,
	texture_handle: Texture_Handle, 
}

Bin_Pack_Node :: struct
{
	size: [2]int,
	rect: util.Rect,
	left_child: int,
	right_child: int,
}

Bin_Pack_Tree :: struct
{
	nodes: [dynamic]Bin_Pack_Node,
}
