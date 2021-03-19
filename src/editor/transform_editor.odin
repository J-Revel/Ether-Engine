package editor;

import "core:fmt"
import "core:log"
import "core:math"

import "../../libs/imgui"

import "../objects"
import "../container"
import "../input"

import "../render"


transform_hierarchy_editor :: proc(
	using hierarchy: ^objects.Transform_Hierarchy,
	using editor_state: ^Transform_Hierarchy_Editor_State,
	input_state: ^input.State)
{
	imgui.separator();
	cursor := first_element_index;
	index: i32 = 0;
	imgui.push_id("transform hierarchy");
	for cursor > 0
	{
		imgui.push_id(index);
		imgui.dummy(0);
		imgui.same_line(0, f32(20 * levels[cursor-1]));
		if imgui.selectable(names[cursor-1], selected_index == cursor)
		{
			selected_index = cursor;
		}
		cursor = next_elements[cursor-1];
		imgui.pop_id();
		index += 1;
	}

	for i in 0..<len(transforms)
	{
		imgui.text_unformatted(fmt.tprint(i, ":", previous_elements[i]-1, next_elements[i]-1));
	}
	if imgui.button("+")
	{
		objects.transform_hierarchy_add_root(hierarchy, {scale = 1}, "root transform");
	}
	imgui.pop_id();
		
	if selected_index > 0
	{
		imgui.separator();
		imgui.input_string("", &names[selected_index-1]);

		if input.get_key_state(input_state, .Kp_Plus) == .Pressed
		{
			objects.transform_hierarchy_add_leaf(hierarchy, {scale = 1}, handles[selected_index-1], "leaf transform");
		}
		if input.get_key_state(input_state, .Up) == .Pressed
		{
			if input.get_key_state(input_state, .LCtrl) == .Down
			{
				objects.transform_hierarchy_move_element_up(hierarchy, handles[selected_index-1]);
			}
			else if previous_elements[selected_index-1] > 0
			{
				selected_index = previous_elements[selected_index-1];
			}
		}
		if input.get_key_state(input_state, .Down) == .Pressed
		{
			if input.get_key_state(input_state, .LCtrl) == .Down
			{
				objects.transform_hierarchy_move_element_down(hierarchy, handles[selected_index-1]);
			}
			else if next_elements[selected_index-1] > 0
			{
				selected_index = next_elements[selected_index-1];
			}
		}
		if input.get_key_state(input_state, .Right) == .Pressed
		{
			objects.transform_hierarchy_add_level(hierarchy, handles[selected_index-1], 1);
		}
		if input.get_key_state(input_state, .Left) == .Pressed
		{
			objects.transform_hierarchy_add_level(hierarchy, handles[selected_index-1], -1);
		}
		if input.get_key_state(input_state, .Delete) == .Pressed
		{
			to_remove := handles[selected_index-1];
			selected_index = next_elements[selected_index-1];
			objects.transform_hierarchy_remove(hierarchy, to_remove);
		}
	}
	if selected_index > 0
	{
		container_database: container.Database;
		imgui.input_float2("pos", &transforms[selected_index-1].pos.x);
		angle := transforms[selected_index-1].angle * 180 / math.PI;
		if imgui.drag_float("angle", &angle, 1)
		{
			transforms[selected_index-1].angle = angle * math.PI / 180;
		}
		imgui.input_float("scale", &transforms[selected_index-1].scale);
		imgui.separator();
	}
}

draw_transform_gizmo :: proc(transform: ^objects.Transform, color: render.Color, camera: ^render.Camera, viewport: render.Viewport, sprite_renderer: ^render.Sprite_Render_System)
{
	screen_transform_pos := render.world_to_screen(camera, viewport, transform.pos);
	
	render.render_rotated_quad(sprite_renderer, transform.pos, {70, 5} * transform.scale, transform.angle, {0, 0}, color);

	render.render_rotated_quad(sprite_renderer, transform.pos, {70, 5} * transform.scale, transform.angle + math.PI / 2, {0, 0}, color);
}

transform_hierarchy_gizmos :: proc(
		using hierarchy: ^objects.Transform_Hierarchy,
		using editor_state: ^Transform_Hierarchy_Editor_State,
		input_state: ^input.State, 
		camera: ^render.Camera, 
		viewport: render.Viewport, 
		renderer: ^render.Sprite_Render_System)
{
	for cursor := first_element_index; cursor > 0; cursor = next_elements[cursor - 1]
	{
		color := render.Color{0.5, 0.5, 0.5, 0.5};
		if selected_index == cursor
		{
			color = render.Color{1, 0, 0, 1};
		}
		absolute_transform := objects.get_absolute_transform(hierarchy, handles[cursor-1]);
		draw_transform_gizmo(&absolute_transform, color, camera, viewport, renderer);
	}
}