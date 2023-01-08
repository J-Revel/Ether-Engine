#version 330 core

uniform vec4 color;
in vec2 uv;

out vec4 out_color;
uniform sampler2D tex;

void main()
{
    out_color = color * texture(tex, uv);
}