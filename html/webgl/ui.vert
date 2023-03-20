attribute vec2 in_position;
attribute vec2 in_uv;
attribute vec4 in_color;

uniform vec2 screen_size;

varying highp vec2 v_uv;
varying lowp vec4 v_color;

void main() {
   gl_Position = vec4((in_position.x / screen_size.x) * 2.0 - 1.0, 1.0 - (in_position.y / screen_size.y) * 2.0, 0, 1);
   v_uv = in_uv;
   v_color = in_color;
}