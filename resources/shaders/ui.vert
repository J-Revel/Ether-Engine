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
	Draw_Command commands[1000];
};

out vec4 frag_color;
out vec2 frag_pos;
out vec2 frag_uv;

uniform vec2 screenSize;

void main()
{
	int primitive_type = gl_VertexID % (1 << 4);
	int primitive_index = (gl_VertexID >> 4) % (1 << 4);
	int vertex_index = gl_VertexID >> 8;

	vec2 pos;
	if(primitive_type == 0)
	{
		Rect rect = draw_commands.commands[primitive_index].rect;
		pos.x = (vertex_index % 2) ? rect.x : rect.x + rect.w;
		pos.y = (vertex_index / 2) ? rect.y : rect.y + rect.h;
		frag_uv.x = (vertex_index % 2) ? rect.clip_x : rect.clip_x + rect.clip_w;
		frag_uv.y = (vertex_index / 2) ? rect.clip_y : rect.clip_y + rect.clip_h;
		frag_color = vec4(rect.color%256, (rect.color >> 8) % 256, (rect.color >> 16) % 256, (rect.color >> 24));
	}
	else
	{

	}
    vec2 screenPos = pos.xy * 2 / screenSize - vec2(1, 1);
    gl_Position = vec4(screenPos.x, -screenPos.y, 0, 1);
}
