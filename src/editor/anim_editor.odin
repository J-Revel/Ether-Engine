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
import "core:reflect"
import "../animation"

import "../geometry"
import "../objects"

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
    widget_size.y = 50;
    
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

	for i in 0..<len(curve.keyframes)-1
	{
		keyframe_1 := curve.keyframes[i];
		keyframe_2 := curve.keyframes[i+1];
		A := [2]f32{keyframe_1.time * widget_size.x, keyframe_1.value * widget_size.y};
        B := [2]f32{keyframe_2.time * widget_size.x, keyframe_2.value * widget_size.y};
        imgui.draw_list_add_line(draw_list, origin + A, origin + B, 0xffffffff);
	}

    if dragging
    {
    	dragged_keyframe := &curve.keyframes[dragged_point];
    	dragged_keyframe.time = relative_mouse_pos.x / widget_size.x;
    	dragged_keyframe.value = relative_mouse_pos.y / widget_size.y;

    	if dragged_point > 0
    	{
    		previous_keyframe := &curve.keyframes[dragged_point-1];
			if previous_keyframe.time > dragged_keyframe.time
			{
				dragged_keyframe^, previous_keyframe^ = previous_keyframe^, dragged_keyframe^;
				dragged_point -= 1;
			}
		}
		if dragged_point < len(curve.keyframes) - 1
    	{
    		next_keyframe := &curve.keyframes[dragged_point+1];
			if next_keyframe.time < dragged_keyframe.time
			{
				dragged_keyframe^, next_keyframe^ = next_keyframe^, dragged_keyframe^;
				dragged_point += 1;
			}
		}
    	
    	for keyframe, index in curve.keyframes
	    {
	        point_pos :=  [2]f32{keyframe.time * widget_size.x, keyframe.value * widget_size.y};
	        distance_to_mouse := linalg.length(relative_mouse_pos - point_pos);
	        fill_color : u32 = 0xffffffff;
	        outline_color : u32 = 0xff000000;
	        if index == dragged_point
	        {
	            fill_color = 0xff00ffff;
	            outline_color = 0xffffffff;
	        }
	    	imgui.draw_list_add_circle_filled(draw_list, origin + point_pos, 3, fill_color, 8);
	    	imgui.draw_list_add_circle(draw_list, origin + point_pos, 3, outline_color, 8, 1);
	    }
	    if imgui.is_mouse_released(imgui.Mouse_Button.Left)
	    {
	    	dragging = false;
	    }
    }
    else
    {
    	hovered_point := -1;
    	insert_index := 0;
    	for keyframe, index in curve.keyframes
	    {
	    	if keyframe.time * widget_size.x < relative_mouse_pos.x do insert_index = index;
	        point_pos :=  [2]f32{keyframe.time * widget_size.x, keyframe.value * widget_size.y};
	        distance_to_mouse := linalg.length(relative_mouse_pos - point_pos);
	        fill_color : u32 = 0xffffffff;
	        outline_color : u32 = 0xff000000;
	        if distance_to_mouse < 5
	        {
	            fill_color = 0xff00ffff;
	            outline_color = 0xffffffff;
	            hovered_point = index;
	        }
	    	imgui.draw_list_add_circle_filled(draw_list, origin + point_pos, 3, fill_color, 8);
	    	imgui.draw_list_add_circle(draw_list, origin + point_pos, 3, outline_color, 8, 1);
	    }
		// Add first and second point
	    if (is_hovered && imgui.is_mouse_clicked(imgui.Mouse_Button.Left))
		{
	    	if hovered_point >= 0
			{
				dragged_point = hovered_point;
				dragging = true;
	    	}
	    }
	    if (is_hovered && imgui.is_mouse_clicked(imgui.Mouse_Button.Right))
	    {
	    	log.info("CLICK");
    		insert_at(&curve.keyframes, insert_index + 1, animation.Keyframe(f32){relative_mouse_pos.x/widget_size.x, relative_mouse_pos.y/widget_size.y});
	    }
    }
}