package render
import "../container"
import "../util"
import "../../libs/freetype"

vec2 :: [2]f32;
Color :: [4]f32;

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

Sprite_Render_Buffer :: struct
{
    vertex: [dynamic]Sprite_Vertex_Data,
    index: [dynamic]u32,
}

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

Sprite_Render_System :: struct
{
    buffer: Sprite_Render_Buffer,
    render_state: Render_State,
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
	sprite: Sprite_Handle,
}

Font :: struct
{
	face: freetype.Face,
	glyphs: map[rune]Glyph,
	line_height: f32,
}

Font_Atlas :: struct
{
	texture_size: [2]int,
	texture_handle: Texture_Handle, 
	pack_tree: Atlas_Tree,
}

/*-------------------------
		Atlas
---------------------------*/

Atlas_Tree_Node :: struct
{
	rect: util.Rect,
	level: int,
	left_child_index: int,
	right_child_index: int,
}

Atlas_Tree :: struct
{

	nodes: [dynamic]Atlas_Tree_Node,
	available_spaces: [dynamic]int,
}
