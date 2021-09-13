#version 450
#extension GL_ARB_bindless_texture : require 

struct Rect_Command
{
	ivec2 pos, size;
	vec2 uv_pos, uv_size;
	uint color;
	uint border_color;
	int border_thickness;
	int corner_radius;
	uvec2 texture_id;
	int clip_index;
};

struct Draw_Command
{
	Rect_Command rect_command;
};

struct Rect
{
	vec2 pos;
	vec2 size;
};

layout(std430, binding=3) readonly buffer draw_commands
{
	Rect clip_rects[256];
	Draw_Command commands[];
};

layout(binding = 4) uniform uni 
{
	ivec2 screen_size;
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
	int command_index = (gl_VertexID >> 16) % (1 << 16);
	vec2 pos_ratio = vec2(((gl_VertexID % 2) > 0 ? 0 : 1), ((gl_VertexID / 2) % 2 > 0 ? 0 : 1));

	Draw_Command draw_command = commands[command_index];
	Rect_Command rect_command = draw_command.rect_command;

	Rect clip = clip_rects[rect_command.clip_index];
	vec2 pos = rect_command.pos + rect_command.size * pos_ratio;
	pos.x = clamp(pos.x, clip.pos.x, clip.pos.x + clip.size.x);
	pos.y = clamp(pos.y, clip.pos.y, clip.pos.y + clip.size.y);
	
	pos_ratio = (pos - rect_command.pos) / rect_command.size;

	vec2 screenPos = pos.xy * 2 / Uniform.screen_size - vec2(1, 1);

	uint r = (rect_command.color >> 24) % 256;
	uint g = (rect_command.color >> 16) % 256;
	uint b = (rect_command.color >> 8) % 256;
	uint a = (rect_command.color) % 256;
	frag_fill_color = vec4(float(r) / 256, float(g) / 256, float(b) / 256, float(a) / 256);

	r = (rect_command.border_color >> 24) % 256;
	g = (rect_command.border_color >> 16) % 256;
	b = (rect_command.border_color >> 8) % 256;
	a = (rect_command.border_color) % 256;

	frag_border_color = vec4(float(r) / 256, float(g) / 256, float(b) / 256, float(a) / 256);
	frag_pos_in_rect = pos - rect_command.pos - rect_command.size / 2;

	frag_rect_half_size = rect_command.size / 2;
	frag_corner_radius = rect_command.corner_radius;
	frag_border_thickness = rect_command.border_thickness;

	gl_Position = vec4(screenPos.x, -screenPos.y, 0, 1);

	frag_uv = vec2(rect_command.uv_pos + rect_command.uv_size * pos_ratio);
	frag_texture_id = rect_command.texture_id;
}
