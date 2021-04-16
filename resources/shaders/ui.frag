#version 450

in vec4 frag_fill_color;
in vec4 frag_border_color;
in vec2 frag_pos_in_rect;

in vec2 frag_rect_half_size;
in float frag_corner_radius;
in float frag_border_thickness;

layout (location = 0) out vec4 out_color;
uniform sampler2D tex;

float rect_sdf(vec2 pos_from_center, vec2 half_rect_size)
{
	return length(max(abs(pos_from_center) - half_rect_size, ivec2(0, 0)));
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
	float border_distance = clamp(0.5 - sdf_border_distance, 0, 1);
	float outer_distance = clamp(0.5 - sdf_distance, 0, 1);

	if(is_inside)
	{
		if(is_border)
		{
			out_color = frag_border_color * (1 - border_distance) + (border_distance) * frag_fill_color;
			out_color.a *= outer_distance;
		}
		else
		{
			out_color = frag_fill_color;
		}
	}
}
