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
	int padding;
};

struct Glyph_Command
{
	ivec2 pos, size;
	vec2 uv_pos, uv_size;
	uint color;
	uvec2 texture_id;
	int clip_index;
	float threshold;
};

struct Draw_Command
{
	int type;
	Rect_Command rect_command;
};

struct Rect
{
	ivec2 pos;
	ivec2 size;
};

layout(std430, binding=3) readonly buffer rect_command_buffer
{
	Rect clip_rects[256];
	Rect_Command rect_commands[];
};

layout(std430, binding=4) readonly buffer glyph_command_buffer
{
	Glyph_Command glyph_commands[];
};

layout(binding = 5) uniform uni 
{
	ivec2 screen_size;
} Uniform;


out vec4 frag_fill_color;
out vec4 frag_border_color;
out vec2 frag_pos_in_rect;

out vec2 frag_rect_half_size;
out float frag_corner_radius;

out float frag_border_thickness;
flat out uvec2 frag_texture_id; 
out vec2 frag_uv;

flat out uint primitive_type;
flat out uint command_index;

void main()
{
	uint vertex_index = gl_VertexID;
	command_index = (vertex_index >> 16) % (1 << 16);
	primitive_type = (vertex_index >> 2) % (1 << 4);
	vec2 pos_ratio = vec2(((vertex_index % 2) > 0 ? 0 : 1), ((vertex_index / 2) % 2 > 0 ? 0 : 1));

	Rect_Command rect_command = rect_commands[command_index];
	Glyph_Command glyph_command = glyph_commands[command_index];
	Rect clip;
	vec2 pos;
	vec2 screenPos;
	uint r;
	uint g;
	uint b;
	uint a;

	switch(primitive_type) {
		case 0:
			clip = clip_rects[rect_command.clip_index];
			pos = rect_command.pos + rect_command.size * pos_ratio;
			pos.x = clamp(pos.x, clip.pos.x, clip.pos.x + clip.size.x);
			pos.y = clamp(pos.y, clip.pos.y, clip.pos.y + clip.size.y);
			
			pos_ratio = (pos - rect_command.pos) / rect_command.size;

			screenPos = pos.xy * 2 / Uniform.screen_size - vec2(1, 1);

			r = (rect_command.color >> 24) % 256;
			g = (rect_command.color >> 16) % 256;
			b = (rect_command.color >> 8) % 256;
			a = (rect_command.color) % 256;
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
			break;
		case 1:
			clip = clip_rects[glyph_command.clip_index];
			pos = glyph_command.pos + glyph_command.size * pos_ratio;
			pos.x = clamp(pos.x, clip.pos.x, clip.pos.x + clip.size.x);
			pos.y = clamp(pos.y, clip.pos.y, clip.pos.y + clip.size.y);
			
			pos_ratio = (pos - glyph_command.pos) / glyph_command.size;

			screenPos = pos.xy * 2 / Uniform.screen_size - vec2(1, 1);

			r = (glyph_command.color >> 24) % 256;
			g = (glyph_command.color >> 16) % 256;
			b = (glyph_command.color >> 8) % 256;
			a = (glyph_command.color) % 256;
			frag_fill_color = vec4(float(r) / 256, float(g) / 256, float(b) / 256, float(a) / 256);

			frag_pos_in_rect = pos - glyph_command.pos - glyph_command.size / 2;

			frag_rect_half_size = glyph_command.size / 2;

			gl_Position = vec4(screenPos.x, -screenPos.y, 0, 1);

			frag_uv = vec2(glyph_command.uv_pos + glyph_command.uv_size * pos_ratio);
			frag_texture_id = glyph_command.texture_id;
			break;
	}
}
