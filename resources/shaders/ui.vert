#version 450

struct Rect 
{
	float x, y, w, h;
	float clip_x, clip_y, clip_w, clip_h;
	int color;
};

struct Circle
{
	float x, y, r;
	int color;
	int subdivisions;
};

struct Draw_Command
{
	Rect rect;
	Circle circle;
};

layout(std430, binding=3) readonly buffer draw_commands
{
	Draw_Command commands[];
};

out vec4 frag_color;
out vec2 frag_pos;
out vec2 frag_uv;

uniform vec2 screenSize;

void main()
{
	vec2 pos;
	pos.x = (gl_VertexID % 2) > 0 ? 0 : 1;
	pos.y = (gl_VertexID / 2) > 0 ? 0 : 1;
	frag_uv.x = 0;
	frag_uv.y = 0;
	frag_color = vec4(1, 1, 1, 1);
    gl_Position = vec4(pos, 0, 1);
}
