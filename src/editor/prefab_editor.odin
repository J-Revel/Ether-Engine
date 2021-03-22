package editor

import imgui "../../libs/imgui";
import "core:log"
import "core:strings"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:reflect"
import "core:slice"
import "core:os"
import "core:encoding/json"
import sdl "shared:odin-sdl2"
import gl "shared:odin-gl";

import "../geometry"
import "../gameplay"
import "../render"
import "../container"
import "../objects"
import "../animation"
import "../input"
import "../serialization"

init_prefab_editor :: proc(using editor_state: ^Prefab_Editor_State, sprite_database: ^render.Sprite_Database)
{
	gameplay.init_empty_scene(&scene, sprite_database);

	container.database_add(&editor_database, sprite_database);
	container.database_add(&editor_database, &transform_hierarchy);

	objects.transform_hierarchy_init(&transform_hierarchy, 5000);
	for type in objects.default_input_types
	{
		append(&input_types, type);
	}

	for component_type in &scene.prefab_tables.component_types
	{
		component_editor_callbacks[component_type.handle_type_id] = handle_component_editor_callback;
		append(&input_types, objects.Prefab_Input{component_type.name, component_type});
	}

	component_editor_callbacks[typeid_of([]animation.Animation_Param)] = animation_player_editor_callback;
	component_editor_callbacks[typeid_of(render.Sprite_Handle)] = sprite_editor_callback;
	
	component_editor_callbacks[typeid_of(objects.Transform_Hierarchy_Handle)] = transform_editor_callback;
}

update_prefab_editor :: proc(using editor_state: ^Prefab_Editor_State, input_state: ^input.State, viewport: render.Viewport)
{
	io := imgui.get_io();
	
	extensions := []string{".prefab"};
	search_config := File_Search_Config{
			start_folder = "config/prefabs", 
			filter_type = .Show_With_Ext, 
			extensions = extensions, 
			hide_folders = false, 
			can_create = false, 
			confirm_dialog = false
		};
	path, file_search_state := file_selector_popup_button("prefab_load", "Load Prefab", search_config);
	
	if file_search_state == .Found
	{
		metadata_dispatcher: objects.Load_Metadata_Dispatcher;
		sprite_metadata_dispatch_table := objects.init_load_metadata_dispatch_type(&metadata_dispatcher, render.Sprite_Handle, render.Sprite_Asset);
		loaded_prefab, success := objects.load_prefab(path, &scene.prefab_tables, &metadata_dispatcher, context.allocator);
		clear(&components);
		for component in loaded_prefab.components
		{
			append(&components, component);
		}
		clear(&inputs);
		for input in loaded_prefab.inputs
		{
			input_data: Prefab_Editor_Input;
			data_type_info: runtime.Type_Info;
			switch input_type in input.type
			{
				case objects.Primitive_Type:
					data_type_info := type_info_of(input_type);
				case objects.Component_Type:
					data_type_info := type_info_of(input_type.type_id);
			}
			input_data.display_value = mem.alloc(data_type_info.size, data_type_info.align);
			append(&inputs, input_data);
		}
		it := container.table_iterator(sprite_metadata_dispatch_table);
		for load_metadata in container.table_iterate(&it)
		{
			//sprite_handle, _ := render.get_or_load_sprite(cast(^render.Sprite_Asset)load_metadata.data);
			prefab_field: Prefab_Field;
			prefab_field.component_index = load_metadata.component_index;
			prefab_field.offset_in_component = load_metadata.offset_in_component;
			prefab_field.type_id = typeid_of(render.Sprite_Handle);
			using comp_model_data := &components[load_metadata.component_index].data;

			new_temp_metadata := cast(^render.Sprite_Asset)load_metadata.data;
			metadata_copy := render.Sprite_Asset{
				strings.clone(new_temp_metadata.path),
				strings.clone(new_temp_metadata.sprite_id),
			};
			new_metadata := to_type_specific_metadata_raw(prefab_field.type_id, &metadata_copy, type_info_of(render.Sprite_Asset));
			set_component_field_metadata(components[:], prefab_field, new_metadata);
			log.info(cast(^render.Sprite_Asset)load_metadata.data);
			// log.info(get_component_field_metadata(components[:], prefab_field));
		}
		//delete(loaded_prefab.components);
	}

	if io.key_ctrl && io.keys_down[sdl.Scancode.W] && !z_down
	{
		undo_history(editor_state);
	}
	z_down = io.keys_down[sdl.Scancode.W];
	if imgui.collapsing_header("Inputs")
	{
		imgui.columns(2);
		imgui.set_column_width(0, 150);
		for input, index in &inputs
		{
			imgui.push_id(fmt.tprintf("input_%d", index));
			imgui.input_string("name", &input.name);
			imgui.next_column();

			selected_input_type := 0;
			for input_type, index in input_types
			{
				if objects.is_same_input_type(input_type.type, input.type)
				{
					selected_input_type = index;
				}
			}
			if imgui.begin_combo("type", input_types[selected_input_type].name, .PopupAlignLeft)
			{
				for input_type, index in input_types
				{
					if imgui.selectable(input_type.name, objects.is_same_input_type(input_type.type, input.type))
					{
						log.info(input_type);
						input.type = input_type.type;
						mem.free(input.display_value);
						switch input_type in input.type
						{
							case objects.Primitive_Type:
								input.display_value = mem.alloc(reflect.size_of_typeid(input_type));
							case objects.Component_Type:
								input.display_value = mem.alloc(reflect.size_of_typeid(input_type.type_id));
						}

					}
				}
				imgui.end_combo();
			}

			input_component_data: objects.Component_Model_Data = {
				data = input.display_value
			};
			// not in default_input_types == component type
			input_component_model: objects.Component_Model = {
				data = input_component_data,
			};
			prefab := Editor_Prefab{
				prefab_tables = &scene.prefab_tables,
				components = []objects.Component_Model{input_component_model}
			};

			field := Component_Field {
				offset_in_component = 0,
			};

			must_change_column := false;
			switch input_type in input.type
			{
				case objects.Primitive_Type:
					field.type_id = input_type;
				case objects.Component_Type:
					type_info := type_info_of(input_type.type_id);
					named_type_info, is_named_type := type_info.variant.(runtime.Type_Info_Named);
					if is_named_type do field.type_id = named_type_info.base.id;
					else do field.type_id = input_type.type_id;
					must_change_column = true;
			}
			if component_field_body(prefab, fmt.tprintf("input%i", index), {field, 0}, component_editor_callbacks, &scene.scene_database)
			{
				record_history_step(editor_state);
			}
			imgui.pop_id();
			if !must_change_column do imgui.next_column();
		}
		imgui.columns(1);
		if imgui.button("Add Input") do append(&inputs, Prefab_Editor_Input{});
		imgui.separator();
	}
	if imgui.collapsing_header("Components")
	{
		to_remove: int;
		for component, index in &components
		{
			imgui.push_id(fmt.tprintf("Component_%d", index));
			flags : imgui.Tree_Node_Flags = .SpanFullWidth | .DefaultOpen;
			table_name := scene.prefab_tables.tables[component.table_index].name;
			imgui.align_text_to_frame_padding();
			component_show := imgui.tree_node_ex("", imgui.Tree_Node_Flags.AllowItemOverlap);
			imgui.same_line();
			available_size: [2]f32;
			imgui.get_content_region_avail(&available_size);
			imgui.set_next_item_width(available_size.x / 2);
			imgui.input_string("Name", &component.id);
			imgui.same_line();
			imgui.set_next_item_width(available_size.x / 4);
			component_table := scene.prefab_tables.tables[component.table_index];
			if imgui.begin_combo("Type", component_table.name, .PopupAlignLeft)
			{
				for named_table, index in scene.prefab_tables.tables
				{
					if imgui.selectable(named_table.name, index == component.table_index)
					{
						component.table_index = index;
						mem.free(component.data.data);
						type_info := type_info_of(named_table.table.type_id);
						component.data.data = mem.alloc(type_info.size, type_info.align);
					}
				}
				imgui.end_combo();
			}
			imgui.next_column();
			
			imgui.columns(1);
			if component_show
			{
				component_type := scene.prefab_tables.tables[components[index].table_index].table.type_id;
				if component_type == typeid_of(objects.Transform)
				{
					if gizmo_state.edited_component == index + 1
					{
						if imgui.button("Hide Gizmos") do gizmo_state.edited_component = 0;
					}
					else if imgui.button("Show Gizmos")
					{
						gizmo_state.edited_component = index + 1;
					}
				}
				component_editor_root({&scene.prefab_tables, components[:], inputs[:]}, index, component_editor_callbacks, &editor_database);
				imgui.columns(1);
				if imgui.button("Remove Component")
				{
					to_remove = index + 1;
					record_history_step(editor_state);
				}
				imgui.tree_pop();
				imgui.separator();
			}
			imgui.pop_id();
		}
		if to_remove > 0
		{
			record_history_step(editor_state);
			remove_component(editor_state, to_remove - 1);
		}
		if(imgui.button("+"))
		{
			component: objects.Component_Model;
			component.id = fmt.aprint("component", len(components));
			type_info := type_info_of(scene.prefab_tables.tables[0].table.type_id);
			component.data.data = mem.alloc(type_info.size, type_info.align);
			append(&components, component);
			record_history_step(editor_state);
		}
		imgui.separator();
	}

	search_config = File_Search_Config{
		start_folder = "config/prefabs", 
		filter_type = .Show_With_Ext, 
		extensions = extensions, 
		hide_folders = false, 
		can_create = true, 
		confirm_dialog = true,
	};
	path, file_search_state = file_selector_popup_button("prefab_save", "Save Prefab", search_config);

	if file_search_state == .Found
	{
		save_prefab_to_json(editor_state, path);
	}

	// if imgui.button("Update Display")
	{
		for table in &scene.prefab_tables.tables
		{
			container.table_clear_raw(&table.table);
		}
		objects.clear_transform_hierarchy(&scene.transform_hierarchy);
		for to_free in allocated_data
		{
			mem.free(to_free);
		}
		clear(&allocated_data);
		input_values: map[string]any;
		input_data := make([]objects.Prefab_Input, len(inputs), context.temp_allocator);
		for input, index in inputs
		{
			input_data[index] = input;
			switch input_type in input.type
			{
				case objects.Primitive_Type:
					input_values[input.name] = any{input.display_value, input_type};
				case objects.Component_Type:
					type_info := type_info_of(input_type.type_id);
					
					table, table_index, table_found := objects.db_get_table(&scene.prefab_tables, input_type.name);
					assert(table_found);
					component, add_ok := container.table_add_raw(&table, input.display_value);
					assert(add_ok);
					handle_data := mem.alloc(size_of(container.Raw_Handle), align_of(container.Raw_Handle));
					mem.copy(handle_data, &component, size_of(container.Raw_Handle));
					append(&allocated_data, handle_data);
					input_values[input.name] = any{handle_data, input_type.type_id};
			}
		}

		metadata_dispatcher: objects.Instantiate_Metadata_Dispatcher;
		sprite_metadata_dispatch_table := objects.init_instantiate_metadata_dispatch_type(&metadata_dispatcher, render.Sprite_Handle);
		transform_metadata_dispatch_table := objects.init_instantiate_metadata_dispatch_type(&metadata_dispatcher, objects.Transform_Hierarchy_Handle);

		components, new_transforms, success := objects.components_instantiate(
			&scene.prefab_tables, 
			&transform_hierarchy, 
			components[:], 
			input_data, 
			input_values,
			&metadata_dispatcher,
			&scene.scene_database,
		);
		sprite_it := container.table_iterator(sprite_metadata_dispatch_table);
		for sprite_metadata in container.table_iterate(&sprite_it)
		{
			assert(sprite_metadata.metadata_type_id == typeid_of(render.Sprite_Asset));
			sprite_asset := cast(^render.Sprite_Asset)sprite_metadata.metadata;
			component_data := container.handle_get_raw(components[sprite_metadata.component_index].value);
			target_sprite_handle := cast(^render.Sprite_Handle)(uintptr(component_data) + sprite_metadata.offset_in_component);
			ok: bool;
			target_sprite_handle^, ok = render.get_or_load_sprite(scene.sprite_database, sprite_asset^);
			// assert(ok);
		}
		transform_it := container.table_iterator(transform_metadata_dispatch_table);
		for transform_metadata in container.table_iterate(&transform_it)
		{
			assert(transform_metadata.metadata_type_id == typeid_of(objects.Transform_Metadata));
			prefab_transform_handle := (cast(^objects.Transform_Metadata)transform_metadata.metadata).transform_handle;
			component_data := container.handle_get_raw(components[transform_metadata.component_index].value);
			target_transform_handle := cast(^objects.Transform_Hierarchy_Handle)(uintptr(component_data) + transform_metadata.offset_in_component);
			
			spawned_transform_handle: objects.Transform_Hierarchy_Handle;
			for instance_transform in new_transforms
			{
				if instance_transform.origin == prefab_transform_handle
				{
					target_transform_handle^ = instance_transform.target;
					break;
				}
			}
		}

		assert(success);
	}
	empty_input_state: input.State;
	gameplay.update_and_render(&scene, 0, &empty_input_state, viewport);
	sprite_it := container.table_iterator(&scene.sprite_database.sprites);
	for sprite, sprite_handle in container.table_iterate(&sprite_it)
	{
		imgui.text_unformatted(fmt.tprint(sprite));
	}
	scene_viewport := render.Viewport{
		viewport.top_left,
		{viewport.size.x / 2, viewport.size.y}
	};

	update_gizmos(editor_state, input_state, &scene.camera, scene_viewport);
	gameplay.do_render(&scene, scene_viewport);

	transform_hierarchy_editor(
		&transform_hierarchy, 
		&transform_editor_state, 
		input_state,
	);
	transform_hierarchy_gizmos(
		&transform_hierarchy, 
		&transform_editor_state,
		input_state, &scene.camera,
		scene_viewport, 
		&editor_state.scene.sprite_renderer,
	);
	ui_print_transform_hierarchy(&scene.transform_hierarchy);
}

get_editor_transform_absolute :: proc(components: []objects.Component_Model, component_index: int) -> (position: [2]f32, angle: f32, scale: f32)
{
	scale = 1;
	field := reflect.struct_field_by_name(typeid_of(objects.Transform), "parent");

	parent_field := Prefab_Field {
		component_field = Component_Field {
			name = "parent",
			offset_in_component = field.offset,
		},
		component_index = component_index,
	};

	for parent_field.component_index >= 0
	{
		transform : ^objects.Transform = get_component_data(components, parent_field.component_index, objects.Transform);
		position += transform.pos;
		scale *= transform.scale;
		imgui.text_unformatted(fmt.tprint(parent_field.component_index, position));
		{
			comp_data := components[parent_field.component_index].data;
		}
		metadata_index := get_component_field_metadata_index(components, parent_field);
		imgui.text_unformatted(fmt.tprint("Metadata index : ", metadata_index));
		if metadata_index >= 0
		{
			metadata, ok := components[parent_field.component_index].data.metadata[metadata_index].(objects.Ref_Metadata);
			parent_field.component_index = ok ? metadata.component_index : -1;
		}
		else
		{
			parent_field.component_index = -1;
		}
	}
	return;
}

draw_gizmo :: proc(components: []objects.Component_Model, component_index: int, color: render.Color, camera: ^render.Camera, viewport: render.Viewport, sprite_renderer: ^render.Sprite_Render_System)
{
	transform : ^objects.Transform = get_component_data(components[:], component_index, objects.Transform);
		
	io := imgui.get_io();
	world_transform_pos, world_transform_angle, world_transform_scale := get_editor_transform_absolute(components[:], component_index);
	screen_transform_pos := render.world_to_screen(camera, viewport, world_transform_pos);
	
	render.render_quad(sprite_renderer, world_transform_pos, {70, 5}, color);

	screen_transform_pos = render.world_to_screen(camera, viewport, world_transform_pos + [2]f32{0, 70});
	render.render_quad(sprite_renderer, world_transform_pos + [2]f32{0, 70}, {5, 70}, color);
}

update_gizmos :: proc(using editor_state: ^Prefab_Editor_State, input_state: ^input.State, camera: ^render.Camera, viewport: render.Viewport)
{
	using gizmo_state;
	for _, component_index in components
	{
		draw_gizmo(components[:], component_index, render.Color{0.5, 0.5, 0.5, 0.5}, camera, viewport, &scene.sprite_renderer);
	}
	if edited_component > 0
	{
		transform : ^objects.Transform = get_component_data(components[:], edited_component-1, objects.Transform);
		
		color: render.Color = {1, 1, 1, 1};
		io := imgui.get_io();
		world_transform_pos, world_transform_angle, world_transform_scale := get_editor_transform_absolute(components[:], edited_component-1);
		screen_transform_pos := render.world_to_screen(camera, viewport, world_transform_pos);
		imgui.text_unformatted(fmt.tprint(world_transform_pos));

		if geometry.is_in_rect(geometry.Rect(int){screen_transform_pos, {70, 5}}, input_state.mouse_pos)
		{
			color = {1, 0, 0, 1};
			if input.get_mouse_state(input_state, 0) == .Pressed
			{
				dragging = true;
				drag_action = .Translate_X;
				drag_start_pos = input_state.mouse_pos;
			}
		}
		render.render_quad(&scene.sprite_renderer, world_transform_pos, {70, 5}, color);

		color = {1, 1, 1, 1};
		screen_transform_pos = render.world_to_screen(camera, viewport, world_transform_pos + [2]f32{0, 70});
		if geometry.is_in_rect(geometry.Rect(int){screen_transform_pos, {5, 70}}, input_state.mouse_pos)
		{
			color = {1, 0, 0, 1};
			if input.get_mouse_state(input_state, 0) == .Pressed
			{
				dragging = true;
				drag_action = .Translate_Y;
				drag_start_pos = input_state.mouse_pos;
			}
		}
		render.render_quad(&scene.sprite_renderer, world_transform_pos + [2]f32{0, 70}, {5, 70}, color);

		if dragging
		{
			if !input.is_down(input.get_mouse_state(input_state, 0))
			{
				dragging = false;
			}
			#partial switch drag_action
			{
				case .Translate_X:
					transform.pos.x += linalg.to_f32(input_state.mouse_pos - drag_start_pos).x / camera.zoom;
					drag_start_pos = input_state.mouse_pos;
				case .Translate_Y:
					transform.pos.y -= linalg.to_f32(input_state.mouse_pos - drag_start_pos).y / camera.zoom;
					drag_start_pos = input_state.mouse_pos;
			}
		}
	}
}

get_component_field_data :: proc
{
	get_component_field_data_raw,
	get_component_field_data_typed
};

get_component_data :: proc(components: []objects.Component_Model, component_index: int, $T: typeid) -> ^T
{
	return cast(^T)components[component_index].data.data;
}

get_component_field_data_raw :: proc(components: []objects.Component_Model, using field: Prefab_Field) -> uintptr
{
	return (uintptr(components[field.component_index].data.data) + field.offset_in_component);
}

get_component_field_data_typed :: proc(components: []objects.Component_Model, using field: Prefab_Field, $T: typeid) -> ^T
{
	return cast(^T)(uintptr(components[field.component_index].data.data) + field.offset_in_component);
}

get_component_field_metadata_index :: proc(components: []objects.Component_Model, field: Prefab_Field) -> int
{
	using components[field.component_index].data;
	for index in 0..<metadata_count
	{
		if metadata_offsets[index] == field.offset_in_component
		{
			return index;
		}
	}
	return -1;
}

set_component_field_metadata :: proc(components: []objects.Component_Model, field: Prefab_Field, new_data: objects.Component_Field_Metadata)
{
	metadata_index := get_component_field_metadata_index(components, field);
	
	using components[field.component_index].data;

	if metadata_index < 0
	{
		metadata_index = metadata_count;
		metadata_offsets[metadata_index] = field.offset_in_component;
		metadata_count += 1;
	}
	metadata[metadata_index] = new_data;
}

remove_component_field_metadata :: proc(components: []objects.Component_Model, field: Prefab_Field)
{
	using components[field.component_index].data;
	metadata_index := get_component_field_metadata_index(components, field);
	if metadata_index >= 0 && metadata_count > 0
	{
		metadata[metadata_index] = metadata[metadata_count - 1];
		metadata_types[metadata_index] = metadata_types[metadata_count - 1];
		metadata_offsets[metadata_index] = metadata_offsets[metadata_count - 1];
	}
	if metadata_count > 0 do metadata_count -= 1;
}

slice_remove_at :: proc(array: []$T, to_remove: []int) -> (new_len: int)
{
	log.info("Remove Refs", to_remove);
	if len(array) == 0 do return;
	n := len(array) - 1;
	slice.sort(to_remove[:]);
	for i := len(to_remove) - 1; i >= 0; i -= 1
	{
		slice.swap(array, to_remove[i], n);
		n -= 1;
	}
	return n + 1;
}

remove_component :: proc(using editor_state: ^Prefab_Editor_State, to_remove_index: int)
{
	log.info("Remove component", to_remove_index);
	for component in &components
	{
		metadata_to_remove: [dynamic]int;
		using component.data;
		for metadata_index in 0..<metadata_count
		{
			#partial switch metadata_info in &metadata[metadata_index]
			{
				case objects.Ref_Metadata:
					if metadata_info.component_index == to_remove_index
					{
						append(&metadata_to_remove, metadata_index);
					}
					else if metadata_info.component_index > to_remove_index
					{
						metadata_info.component_index -= 1;
					}
				case objects.Type_Specific_Metadata:
					anim_param_list := get_type_specific_metadata(objects.Anim_Param_List_Metadata, &metadata_info);
					for index in 0..anim_param_list.count
					{
						anim_param := anim_param_list.anim_params[index];
						if anim_param.component_index == to_remove_index
						{
							anim_param_list.anim_params[index].component_index = -1;
						}
						else if anim_param.component_index > to_remove_index
						{
							anim_param_list.anim_params[index].component_index -= 1;
						}
					}
			}
		}

		metadata_count = slice_remove_at(component.data.metadata[0:metadata_count], metadata_to_remove[:]);
	}
	ordered_remove(&components, to_remove_index);
}

input_ref_combo :: proc(using prefab: Editor_Prefab, id: string, field: Prefab_Field) -> bool
{
	modified := false;
	metadata_index := get_component_field_metadata_index(components[:], field);
	
	current_value_name := "nil";
	selected_input_name : string;
	using components[field.component_index].data;

	selected_component_index := -1;
	if metadata_index >= 0 
	{
		switch metadata_info in metadata[metadata_index]
		{
			case objects.Ref_Metadata:
				selected_component_index = metadata_info.component_index;
				current_value_name = fmt.tprintf("(ref)%s", components[selected_component_index].id);

			case objects.Input_Metadata:
				if metadata_info.input_index < 0
				{
					selected_input_name = "nil";
					current_value_name = "nil";
				}
				else
				{
					selected_input_name = inputs[metadata_info.input_index].name;
					current_value_name = fmt.tprintf("(input)%s", selected_input_name);
				}

			case objects.Type_Specific_Metadata:
		}
		
	}

	display_value := current_value_name;

	if imgui.begin_combo(id, display_value, .PopupAlignLeft)
	{
		reference_found, input_found: bool;
		ref_input_index: int;

		for component, index in components
		{
			if prefab_tables.tables[component.table_index].table.handle_type_id == field.type_id 
			{
				if !reference_found do imgui.text_unformatted("References :");
				reference_found = true;
				is_selected := false;
				if imgui.selectable(component.id, selected_component_index == index)
				{
					new_ref := objects.Ref_Metadata{index};

					set_component_field_metadata(components[:], field, new_ref);
					modified = true;
				}
			}
		}
		imgui.separator();

		for input, index in inputs
		{
			ref_input_index = index;
			if objects.can_use_input_type(field.type_id, input.type)
			{
				if !input_found do imgui.text_unformatted("Inputs :");
				input_found = true;
				if imgui.selectable(input.name, selected_input_name == input.name)
				{
					new_input := objects.Input_Metadata{index};
					set_component_field_metadata(components[:], field, new_input);
					modified = true;
				}
			}
		}

		imgui.separator();

		if imgui.selectable("nil", !reference_found && !input_found)
		{
			remove_component_field_metadata(components[:], field);
		}
		imgui.end_combo();
	}
	return modified;
}

//component_editor_root :: proc(using prefab: Editor_Prefab, component_index: int, component_editor_callbacks: map[typeid]Editor_Type_Callback)
component_editor_root :: proc(using prefab: Editor_Prefab, component_index: int, component_editor_callbacks: map[typeid]Editor_Type_Callback, scene_database: ^container.Database)
{
	component := &components[component_index];
	component_table := prefab_tables.tables[component.table_index];
	component_type_id := runtime.typeid_base(component_table.table.type_id);
	if component.data.data == nil
	{
		component_type := type_info_of(component_type_id);
		component.data.data = mem.alloc(component_type.size, component_type.align);
	}
	component_data := any{component.data.data, component_type_id};
	
	field_cursor := Prefab_Field{{component.id, 0, component_type_id}, component_index};
	callback, callback_found := component_editor_callbacks[component_type_id];
	if callback_found
	{
		callback(prefab, field_cursor, scene_database);
		return;
	}
	type_info := type_info_of(component_data.id);
	for
	{
		#partial switch variant in type_info.variant
		{
			case runtime.Type_Info_Struct:
			struct_info, ok := type_info.variant.(runtime.Type_Info_Struct);
			imgui.columns(2);
			imgui.set_column_width(0, 150);
			for _, i in struct_info.names
			{
				field_cursor.offset_in_component = struct_info.offsets[i];
				child_field := Prefab_Field{{struct_info.names[i], struct_info.offsets[i], struct_info.types[i].id}, component_index};
				component_editor_child(prefab, struct_info.names[i], child_field, component_editor_callbacks, scene_database);
			}
			return;

			case runtime.Type_Info_Named:
				type_info = type_info_of(variant.base.id);
		}
	}
}

component_field_header :: proc(using prefab: Editor_Prefab, base_name: string, field: Prefab_Field, component_editor_callbacks: Editor_Type_Callback_List, scene_database: ^container.Database) -> (modified: bool)
{
	type_info := type_info_of(field.type_id);
	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			if imgui.tree_node(base_name)
			{
				imgui.next_column();
				modified |= component_field_body(prefab, base_name, field, component_editor_callbacks, scene_database);
				imgui.next_column();
				imgui.tree_pop();
			}
		case runtime.Type_Info_Named:
			if field.type_id in component_editor_callbacks
			{
				imgui.text_unformatted(base_name);
				imgui.next_column();
				modified |= component_field_body(prefab, base_name, field, component_editor_callbacks, scene_database);
				imgui.next_column();
			}
			else
			{
				child_field := field;
				child_field.type_id = variant.base.id;
				modified |= component_field_header(prefab, base_name, child_field, component_editor_callbacks, scene_database);
			}
			return;
		case:
			imgui.text_unformatted(base_name);
			imgui.next_column();
			modified |= component_field_body(prefab, base_name, field, component_editor_callbacks, scene_database);
			imgui.next_column();
	}
	return;
}

component_field_body :: proc(using prefab: Editor_Prefab, base_name: string, field: Prefab_Field, component_editor_callbacks: Editor_Type_Callback_List, scene_database: ^container.Database) -> (modified: bool)
{
	metadata_index := get_component_field_metadata_index(components[:], field);

	if input_ref_available(prefab, field)
	{
		imgui.button("*");
		if imgui.begin_popup_context_item("ref_input_popup", .MouseButtonLeft)
		{
			struct_field := Prefab_Field
			{
				{
					name = field.name,
					type_id = field.type_id,
					offset_in_component = field.offset_in_component
				},
				field.component_index
			};
			if metadata_index < 0
			{
				ref_input_popup_content(prefab, struct_field);
			}
			else
			{
				button_text: string;
				#partial switch variant in components[field.component_index].data.metadata[metadata_index]
				{
					case objects.Ref_Metadata:
						button_text = "Remove Ref";
					case objects.Input_Metadata:
						button_text = "Remove Input";
				}
				if imgui.button(button_text)
				{
					remove_component_field_metadata(components[:], struct_field);
					imgui.close_current_popup();
				}
			}
			imgui.end_popup();
		}
	}
	else 
	{
		imgui.dummy(17);
	}

	imgui.same_line();
	type_info := type_info_of(field.type_id);
	callback, callback_found := component_editor_callbacks[field.type_id];
	if callback_found
	{
		callback(prefab, field, scene_database);
		return;
	}

	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			imgui.next_column();
			A, B: [2]f32;
			imgui.get_cursor_screen_pos(&A);
			offset_cursor: uintptr = 0;
			for _, i in variant.names
			{
				width := imgui.calc_item_width();
				imgui.push_id(variant.names[i]);
				child_type := variant.types[i];
				child_field: Prefab_Field = {
					{
						variant.names[i], field.offset_in_component + variant.offsets[i], child_type.id
					}, 
					field.component_index
				};
				component_editor_child(prefab, variant.names[i], child_field, component_editor_callbacks, scene_database);
				imgui.pop_id();
			}
			imgui.get_cursor_screen_pos(&B);
		case runtime.Type_Info_Named:
			child_field := field;
			child_field.type_id = variant.base.id;
			component_editor_child(prefab, base_name, child_field, component_editor_callbacks, scene_database);
		case runtime.Type_Info_Integer:
			metadata_index := get_component_field_metadata_index(components[:], field);
			if metadata_index >= 0
			{
				if input_ref_combo(prefab, "", field) do modified = true;
				imgui.same_line();
				if imgui.button("remove input")
				{
					remove_component_field_metadata(components[:], field);
				}
			}
			else
			{
				imgui.push_item_width(imgui.get_window_width() * 0.5);
				if imgui.input_int("", cast(^i32) get_component_field_data(components[:], field))
				{
					modified = true;
				}
				imgui.pop_item_width();
			}
		case runtime.Type_Info_Float:
			imgui.push_item_width(imgui.get_window_width() * 0.5);
			if imgui.input_float("", cast(^f32) get_component_field_data(components[:], field))
			{
				modified = true;
			}
			imgui.same_line();
			if imgui.button("input")
			{
				new_input := objects.Input_Metadata{-1};
				set_component_field_metadata(components[:], field, new_input);
				modified = true;
			}
			imgui.pop_item_width();
		case runtime.Type_Info_String:
			str := cast(^string)get_component_field_data(components[:], field);
			if imgui.input_string("", str, 200)
			{
				modified = true;
				str^ = strings.clone(str^, context.allocator);
			}
		case runtime.Type_Info_Array:
			data_type: imgui.Data_Type = .Count;
			format := "%d";
			switch(variant.elem.id)
			{
				case typeid_of(i32):
					data_type = .S32;
				case typeid_of(u32):
					data_type = .U32;
				case typeid_of(i64):
					data_type = .S64;
				case typeid_of(u64):
					data_type = .U64;
				case typeid_of(int):
					data_type = (size_of(typeid_of(int)) == 8) ? .S64:.S32;
				case typeid_of(f32):
					data_type = .Float;
					format = "%.3f";
				case typeid_of(f64):
					data_type = .Double;
					format = "%.6f";
			}
			if imgui.input_scalar_n("", data_type, rawptr(get_component_field_data(components[:], field)), i32(variant.count), nil, nil, format)
			{
				modified = true;
			}

			if data_type == .Count
			{
				prefab_field: Prefab_Field = { 
					{ "", field.offset_in_component, variant.elem.id },
					field.component_index
				};
				for i in 0..<variant.count
				{
					prefab_field.offset_in_component = field.offset_in_component + uintptr(variant.elem_size * i);
					imgui.push_id(fmt.tprintf("element_%d", i));
					char := 'x' + i;
					txt := fmt.tprintf("%c", char);

					if component_editor_child(prefab, txt, prefab_field, component_editor_callbacks, scene_database) do modified = true;
					imgui.pop_id();
				}
			}
	}
	return modified;

}

component_editor_child :: proc(using prefab: Editor_Prefab, base_name: string, field: Prefab_Field, component_editor_callbacks: Editor_Type_Callback_List, scene_database: ^container.Database) -> (modified: bool)
{
	metadata_index := get_component_field_metadata_index(components[:], field);
	imgui.push_id(base_name);
	modified = component_field_header(prefab, base_name, field, component_editor_callbacks, scene_database);
	imgui.next_column();

	imgui.pop_id();
	imgui.next_column();
	return;
}

input_ref_available :: proc(using prefab: Editor_Prefab, field: Prefab_Field) -> bool
{
	if prefab_tables == nil do return false;

	for component, index in components
	{
		if prefab_tables.tables[component.table_index].table.handle_type_id == field.type_id 
		{
			return true;
		}
	}

	for input, index in inputs
	{
		if objects.can_use_input_type(field.type_id, input.type)
		{
			return true;
		}
	}
	return false;
}

ref_input_popup_content :: proc(using prefab: Editor_Prefab, field: Prefab_Field)
{
	for component, index in components
	{
		if prefab_tables.tables[component.table_index].table.handle_type_id == field.type_id 
		{
			if imgui.button(component.id)
			{
				new_ref := objects.Ref_Metadata{index};

				set_component_field_metadata(components[:], field, new_ref);
				imgui.close_current_popup();
			}
		}
	}
	imgui.separator();

	for input, index in inputs
	{
		if objects.can_use_input_type(field.type_id, input.type)
		{
			imgui.text_unformatted("Inputs :");
			if imgui.button(input.name)
			{
				new_input := objects.Input_Metadata{index};
				set_component_field_metadata(components[:], field, new_input);
				imgui.close_current_popup();
			}
		}
	}
	imgui.separator();
	if imgui.button("Cancel") do imgui.close_current_popup();
}


record_history_step :: proc(using editor_state: ^Prefab_Editor_State)
{
	components_copy := make([]objects.Component_Model, len(components));
	copy(components_copy, components[:]);
	for component, index in &components_copy
	{
		component_table := scene.prefab_tables.tables[component.table_index];
		component_type_id := runtime.typeid_base(component_table.table.type_id);
		component_type := type_info_of(component_type_id);
		component.data.data = mem.alloc(component_type.size, component_type.align);
		mem.copy(component.data.data, components[index].data.data, component_type.size);
		component.id = strings.clone(components[index].id, context.allocator);
	}
	append(&components_history, components_copy);
}

undo_history :: proc(using editor_state: ^Prefab_Editor_State)
{
	if len(components_history) == 0 do return;
	backup_components := pop(&components_history);
	clear(&components);
	for component in backup_components
	{
		component_table := scene.prefab_tables.tables[component.table_index];
		component_type_id := runtime.typeid_base(component_table.table.type_id);
		component_type := type_info_of(component_type_id);
		log.info(any{component.data.data, component_type_id});
		append(&components, component);
	}
	delete(backup_components);
}

save_prefab_to_json :: proc(using editor_state: ^Prefab_Editor_State, path: string)
{
	file, errno := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC);
	if errno == 0
	{
		write_state: serialization.Json_Write_State;
		serialization.json_write_open_body(file, &write_state);
		serialization.json_write_member(file, "inputs", &write_state);
		serialization.json_write_open_body(file, &write_state, "[");
		{
			for input in inputs
			{
				serialization.json_write_open_body(file, &write_state);

				serialization.json_write_member(file, "name", &write_state);
				serialization.json_write_value(file, input.name, &write_state);
				serialization.json_write_member(file, "type", &write_state);

				input_types := objects.get_input_types_list(&scene.prefab_tables);
				for input_type in input_types
				{
					// TODO : if type_id is nil, empty type
					if objects.is_same_input_type(input_type.type, input.type) do serialization.json_write_value(file, input_type.name, &write_state);
				}

				serialization.json_write_close_body(file, &write_state);
			}
		}
		serialization.json_write_close_body(file, &write_state, "]");
		write_state.has_precedent = true;
		serialization.json_write_member(file, "components", &write_state);
		serialization.json_write_open_body(file, &write_state);
		{
			for component in components
			{
				serialization.json_write_member(file, component.id, &write_state);
				serialization.json_write_open_body(file, &write_state);
				serialization.json_write_member(file, "type", &write_state);
				component_table := scene.prefab_tables.tables[component.table_index];
				serialization.json_write_value(file, component_table.name, &write_state);
				component_type_id := runtime.typeid_base(component_table.table.type_id);
				type_info := type_info_of(component_type_id);

				for type_info != nil
				{
					#partial switch variant in type_info.variant
					{
						case runtime.Type_Info_Struct:
						struct_info, ok := type_info.variant.(runtime.Type_Info_Struct);
						for name, index in struct_info.names
						{
							serialization.json_write_member(file, name, &write_state);
							json_write_component_member(file, editor_state, component.data, struct_info.types[index], struct_info.offsets[index], &write_state);
						}
						type_info = nil;

						case runtime.Type_Info_Named:
							type_info = type_info_of(variant.base.id);

					}
				}

				serialization.json_write_close_body(file, &write_state);
				
			}
		}
		serialization.json_write_close_body(file, &write_state);
		serialization.json_write_close_body(file, &write_state);
		os.close(file);
	}
	else
	{
		log.error("Error trying to save to file", path, ":", errno);
	} 
}

json_write_metadata :: proc(file: os.Handle, metadata: objects.Type_Specific_Metadata, write_state: ^serialization.Json_Write_State)
{
	serialization.json_write_open_body(file, write_state);
	serialization.json_write_struct(file, metadata.data, type_info_of(metadata.metadata_type_id), write_state);

	serialization.json_write_close_body(file, write_state);
}

json_write_component_member :: proc(file: os.Handle, using editor_state: ^Prefab_Editor_State, component: objects.Component_Model_Data, type_info: ^runtime.Type_Info, offset: uintptr, write_state: ^serialization.Json_Write_State)
{
	for index in 0..<component.metadata_count
	{
		if component.metadata_offsets[index] == offset
		{
			switch metadata in component.metadata[index]
			{
				case objects.Ref_Metadata:
					serialization.json_write_ref(file, components[metadata.component_index].id, write_state);
				case objects.Input_Metadata:
					serialization.json_write_input(file, metadata.input_index, write_state);
				case objects.Type_Specific_Metadata:
					json_write_metadata(file, metadata, write_state);
			}
			return;
		}
	}

	for component_type in scene.prefab_tables.component_types
	{
		if component_type.handle_type_id == type_info.id
		{
			serialization.json_write_value(file, "nil", write_state);
			return;
		}
	} 

	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			serialization.json_write_open_body(file, write_state);
			struct_info, ok := type_info.variant.(runtime.Type_Info_Struct);
			for name, index in struct_info.names
			{
				serialization.json_write_member(file, name, write_state);
				json_write_component_member(file, editor_state, component, struct_info.types[index], offset + struct_info.offsets[index], write_state);
			}
			serialization.json_write_close_body(file, write_state);

		case runtime.Type_Info_Named:
			json_write_component_member(file, editor_state, component, type_info_of(variant.base.id), offset, write_state);
		case runtime.Type_Info_Float:
			os.write_string(file, fmt.tprint((cast(^f32)(uintptr(component.data) + offset))^));
			write_state.has_precedent = true;
		case runtime.Type_Info_Integer:
			os.write_string(file, fmt.tprint(any{rawptr(uintptr(component.data) + offset), type_info.id}));
			write_state.has_precedent = true;
		case runtime.Type_Info_String:
			serialization.json_write_value(file, (cast(^string)(uintptr(component.data) + offset))^, write_state);
			write_state.has_precedent = true;
		case runtime.Type_Info_Array:
			os.write_byte(file, '[');
			write_state.tab_count += 1;
			for i in 0..<variant.count
			{
				if i > 0 do os.write_string(file, ", ");
				component_data := component.data;
				element_size := variant.elem_size;
				json_write_component_member(file, editor_state, component, variant.elem, offset + uintptr(i * variant.elem_size), write_state);
			}
			os.write_byte(file, ']');
			write_state.has_precedent = true;
			write_state.tab_count -= 1;
	}
}