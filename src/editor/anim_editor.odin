package editor

import imgui "../imgui";
import "../render"
import "core:log"
import "core:strings"
import "../container"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"
import "../animation"

import "../geometry"

init_anim_editor :: proc(using editor_state: ^Anim_Editor_State)
{
	anim_curve.keyframes = make([dynamic]animation.Keyframe(f32));
	append(&anim_curve.keyframes, animation.Keyframe(f32){0, 1});
	append(&anim_curve.keyframes, animation.Keyframe(f32){0.5, 0.3});
	append(&anim_curve.keyframes, animation.Keyframe(f32){1, 0.5});
}

curve_editor :: proc(using curve_editor_state: ^Curve_Editor_State, curve: ^animation.Dynamic_Animation_Curve($T))
{

	start_pos, widget_size: [2]f32;
	imgui.get_cursor_screen_pos(&start_pos);
    imgui.get_content_region_avail(&widget_size);   // Resize canvas to what's available
    if (widget_size.x < 50) do widget_size.x = 50;
    if (widget_size.y < 50) do widget_size.y = 50;
    
    // Draw border and background color
    io := imgui.get_io();
    draw_list := imgui.get_window_draw_list();
    imgui.draw_list_add_rect_filled(draw_list, start_pos, start_pos + widget_size, 0xff444444);
   	imgui.draw_list_add_rect(draw_list, start_pos, start_pos + widget_size, 0xffffffff);

    // This will catch our interactions
    imgui.invisible_button("canvas", widget_size, .MouseButtonLeft | .MouseButtonRight);
    is_hovered := imgui.is_item_hovered();
    is_active := imgui.is_item_active();
    origin := start_pos + scrolling;

    relative_mouse_pos := io.mouse_pos - origin;
    
    imgui.text(fmt.tprint(is_hovered, is_active));

    for keyframe in curve.keyframes
    {
    	imgui.draw_list_add_circle_filled(draw_list, origin + [2]f32{keyframe.time * widget_size.x, keyframe.value * widget_size.y}, 3, 0xffff5555, 8);
    	imgui.draw_list_add_circle(draw_list, origin + [2]f32{keyframe.time * widget_size.x, keyframe.value * widget_size.y}, 3, 0xffffffff, 8, 1);
    }

    // Add first and second point
    // if (is_hovered && imgui.mouse_clicked(imgui.Mouse_Button.Left))
    // {

    // }

}