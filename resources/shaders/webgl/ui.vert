attribute vec2 in_position;
attribute vec2 in_uv;

uniform vec2 screen_size;

void main() {

   gl_Position = vec4((in_position.x / screen_size.x) * 2 - 1, (in_position.y / screen_size.y) * 2 - 1, 0, 1);
}