#version 450

struct Rect 
{
	ivec2 pos, size;
	vec2 clip_pos, clip_size;
	uint color;
	uint border_color;
	float border_thickness;
	float corner_radius;
};


struct Draw_Command
{
	Rect rect;
};

layout(std430, binding=3) readonly buffer draw_commands
{
	Draw_Command commands[];
};

out vec4 frag_fill_color;
out vec4 frag_border_color;
out vec2 frag_pos_in_rect;

out vec2 frag_rect_half_size;
out float frag_corner_radius;

out float frag_border_thickness;


uniform vec2 screenSize;

void main()
{
	vec2 pos;
	int command_index = gl_VertexID >> 8;
	Rect rect = commands[command_index].rect;
	pos.x = (gl_VertexID % 2) > 0 ? float(rect.pos.x) : float(rect.pos.x + rect.size.x);
	pos.y = (gl_VertexID / 2) % 2 > 0 ? float(rect.pos.y) : float(rect.pos.y + rect.size.y);

    vec2 screenPos = pos.xy * 2 / screenSize - vec2(1, 1);

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
}
