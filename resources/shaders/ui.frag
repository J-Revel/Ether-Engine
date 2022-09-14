#version 450
#extension GL_ARB_bindless_texture : require 

in vec4 frag_fill_color;
in vec4 frag_border_color;
in vec2 frag_pos_in_rect;

in vec2 frag_rect_half_size;
in float frag_corner_radius;
in float frag_border_thickness;

flat in uvec2 frag_texture_id;
in vec2 frag_uv;
flat in uint primitive_type;
flat in uint command_index;

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
	float threshold;
};

struct Rect
{
	ivec2 pos;
	ivec2 size;
};

layout (location = 0) out vec4 out_color;

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

float rect_sdf(vec2 pos_from_center, vec2 half_rect_size)
{
	return length(max(abs(pos_from_center) - half_rect_size, 0));
}

float rounded_rect_sdf(vec2 pos_from_center, vec2 half_rect_size, float corner_radius)
{
	return rect_sdf(pos_from_center, half_rect_size - vec2(corner_radius, corner_radius)) - corner_radius;
}

void main()
{
	float sdf_distance = rounded_rect_sdf(frag_pos_in_rect, frag_rect_half_size, frag_corner_radius);
	float sdf_border_distance = rounded_rect_sdf(frag_pos_in_rect, frag_rect_half_size - vec2(frag_border_thickness, frag_border_thickness), frag_corner_radius);
    bool is_inside = sdf_distance <= 0;
	bool is_border = sdf_border_distance > 0;
	float border_distance = smoothstep(0, 1, 0.5 - sdf_border_distance);
	float outer_distance = smoothstep(0, 1, 0.5 - sdf_distance);
	if(frag_corner_radius == 0)
		outer_distance = 1;
	
	bool has_texture = false;//frag_texture_id.x != 0 || frag_texture_id.y != 0;

	switch(primitive_type) {
		case 0:
			if(frag_border_thickness == 0 && frag_corner_radius == 0)
			{
				if(has_texture)
					out_color = frag_fill_color * texture(sampler2D(frag_texture_id), frag_uv);
				else
					out_color = frag_fill_color;
			}
			else if(is_inside)
			{
				if(is_border)
				{
					out_color = frag_border_color * (1 - border_distance) + (border_distance) * frag_fill_color;
					out_color.a *= outer_distance;
				}
				else
				{
					out_color = frag_fill_color;
					if(has_texture)
					{
						out_color *= texture(sampler2D(frag_texture_id), frag_uv);
					}
				}
			}
			break;
		case 1:
			if(texture(sampler2D(frag_texture_id), frag_uv).x > glyph_commands[command_index].threshold)
				out_color = frag_fill_color;
			else out_color = vec4(0, 0, 0, 0);
			break;
	}
}
