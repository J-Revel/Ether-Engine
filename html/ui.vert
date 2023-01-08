#version 330 core
layout (location = 0) in vec2 in_pos;
layout (location = 1) in vec2 in_uv;

out vec2 uv;

uniform vec2 screenSize;

void main()
{
    vec2 pos = in_pos / screenSize * 2 - 1;
    uv = in_uv;
    gl_Position = vec4(pos.x, - pos.y, 0, 1);
}