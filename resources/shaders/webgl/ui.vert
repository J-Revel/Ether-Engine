attribute vec2 a_position;
attribute vec2 a_uv;

void main() {
   gl_Position = vec4(a_position.x, a_position.y, 0, 1);
}