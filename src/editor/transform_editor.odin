package editor;

import "core:fmt"
import "core:log"
import "core:math"
import "core:reflect"

import "../../libs/imgui"

import "../objects"
import "../container"
import "../input"

import "../render"

transform_editor_callback :: proc(using prefab: Editor_Prefab, field: Prefab_Field, scene_database: ^container.Database)
{
	component := components[field.component_index];
	transform := get_component_field_data(components[:], field, objects.Transform);
	hierarchy := container.database_get(scene_database, objects.Transform_Hierarchy);
	parent_field := field;
	parent_field.offset_in_component = reflect.struct_field_by_name(objects.Transform, "parent").offset;
	metadata_index := get_component_field_metadata_index(components[:], field);
	selected_name: string;
	selected_transform_index: int;
	if metadata_index >= 0
	{
		switch metadata_type in component.data.metadata[metadata_index]
		{
			case objects.Ref_Metadata:
				panic("Ref metadata for transform handle");
			case objects.Input_Metadata:
				panic("Input metadata for transform handle");
			case objects.Type_Specific_Metadata:
				assert(metadata_type.metadata_type_id == typeid_of(objects.Transform_Metadata));
				transform_handle := cast(^objects.Transform_Metadata)metadata_type.data;
				selected_transform_index = container.table_get(&hierarchy.element_index_table, transform_handle.transform_handle)^;
				selected_name = hierarchy.names[selected_transform_index-1];
		}
	}
	if imgui.begin_combo("", selected_name)
	{
		for cursor := hierarchy.first_element_index; cursor > 0; cursor = hierarchy.next_elements[cursor-1]
		{
			if imgui.selectable(hierarchy.names[cursor-1], cursor == selected_transform_index)
			{
				new_transform_metadata := objects.Transform_Metadata{hierarchy.handles[cursor-1]};
				new_metadata := to_type_specific_metadata_raw(field.type_id, &new_transform_metadata, type_info_of(objects.Transform_Metadata));
				set_component_field_metadata(components[:], field, new_metadata);
			}
		}
		imgui.end_combo();
	}

}

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
		imgui.drag_float2("pos", &transforms[selected_index-1].pos, 1);
		angle := transforms[selected_index-1].angle * 180 / math.PI;
		if imgui.drag_float("angle", &angle, 1)
		{
			transforms[selected_index-1].angle = angle * math.PI / 180;
		}
		imgui.drag_float("scale", &transforms[selected_index-1].scale, 0.01);
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

ui_print_transform_hierarchy :: proc(using hierarchy: ^objects.Transform_Hierarchy)
{
	for i in 0..<len(transforms)
	{
		imgui.text_unformatted(fmt.tprint(i, ":", previous_elements[i]-1, next_elements[i]-1));
	}
}