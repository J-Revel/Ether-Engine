#version 450
#extension GL_ARB_bindless_texture : require 

struct Rect 
{
	ivec2 pos, size;
	vec2 uv_pos, uv_size;
	uint color;
	uint border_color;
	float border_thickness;
	float corner_radius;
	uvec2 texture_id;
	int clip_rect_index;
};

struct Draw_Command
{
	Rect rect;
};

layout(std430, binding=3) readonly buffer draw_commands
{
	Rect clip_rects[256];
	Draw_Command commands[];
};

layout(binding = 4) uniform uni 
{
	vec2 screen_size;
} Uniform;


out vec4 frag_fill_color;
out vec4 frag_border_color;
out vec2 frag_pos_in_rect;

out vec2 frag_rect_half_size;
out float frag_corner_radius;

out float frag_border_thickness;
out uvec2 frag_texture_id; 
out vec2 frag_uv;

void main()
{
	vec2 pos;
	int command_index = (gl_VertexID >> 16) % (1 << 16);
	vec2 pos_ratio = vec2(((gl_VertexID % 2) > 0 ? 0 : 1), ((gl_VertexID / 2) % 2 > 0 ? 0 : 1));

	Rect rect = commands[command_index].rect;
	pos = rect.pos + rect.size * pos_ratio;

	vec2 screenPos = pos.xy * 2 / Uniform.screen_size - vec2(1, 1);

	uint r = (rect.color >> 24) % 256;
	uint g = (rect.color >> 16) % 256;
	uint b = (rect.color >> 8) % 256;
	uint a = (rect.color) % 256;
	frag_fill_color = vec4(float(r) / 256, float(g) / 256, float(b) / 256, float(a) / 256);

	r = (rect.border_color >> 24) % 256;
	g = (rect.border_color >> 16) % 256;
	b = (rect.border_color >> 8) % 256;
	a = (rect.border_color) % 256;
	frag_border_color = vec4(float(r) / 256, float(g) / 256, float(b) / 256, float(a) / 256);
	frag_pos_in_rect = pos - rect.pos - rect.size / 2;

	frag_rect_half_size = rect.size / 2;
	frag_corner_radius = rect.corner_radius;
	frag_border_thickness = rect.border_thickness;

	gl_Position = vec4(screenPos.x, -screenPos.y, 0, 1);


	frag_uv = vec2(rect.uv_pos+ rect.uv_size * pos_ratio);
	frag_texture_id = rect.texture_id;
}
