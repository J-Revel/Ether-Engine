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

import "../geometry"
import "../gameplay"
import "../render"
import "../container"
import "../objects"
import "../animation"

handle_component_editor_callback :: proc(using prefab: Editor_Prefab, field: Prefab_Field, scene_database: ^container.Database)
{
	metadata_index := get_component_field_metadata_index(components[:], field);
	current_value_name := "nil";
	component := components[field.component_index];
	if metadata_index >= 0
	{
		switch metadata_content in component.data.metadata[metadata_index]
		{
			case objects.Ref_Metadata:
				current_value_name = fmt.tprintf("(ref)%s", components[metadata_content.component_index].id);

			case objects.Input_Metadata:
				input_index := metadata_content.input_index;
				selected_input_name := inputs[input_index].name;
				current_value_name = fmt.tprintf("(input)%s", selected_input_name);

			case objects.Type_Specific_Metadata:

		}
	}
	imgui.text(current_value_name);
}

to_type_specific_metadata :: proc(field_type_id: typeid, data: $T, allocator := context.allocator) -> (result: objects.Type_Specific_Metadata)
{
	metadata_type_info := type_info_of(T);
	
	result = objects.Type_Specific_Metadata {
		field_type_id = field_type_id,
		metadata_type_id = metadata_type_info.id,
		data = mem.alloc(metadata_type_info.size, metadata_type_info.align, allocator),
	};
	data_copy := data;
	mem.copy(result.data, rawptr(&data_copy), metadata_type_info.size);
	return;
}

to_type_specific_metadata_raw :: proc(field_type_id: typeid, data: rawptr, data_type: ^runtime.Type_Info, allocator := context.allocator) -> (result: objects.Type_Specific_Metadata)
{
	result = objects.Type_Specific_Metadata {
		field_type_id = field_type_id,
		metadata_type_id = data_type.id,
		data = mem.alloc(data_type.size, data_type.align, allocator),
	};
	mem.copy(result.data, data, data_type.size);
	return;
}

get_type_specific_metadata :: #force_inline proc($T: typeid, metadata: ^objects.Type_Specific_Metadata) -> ^T
{
	assert(metadata.metadata_type_id == T);
	return cast(^T)metadata.data;
}


animation_player_editor_callback :: proc(using prefab: Editor_Prefab, field: Prefab_Field, scene_database: ^container.Database)
{
	selected_metadata_index := get_component_field_metadata_index(components[:], field);
	component_data := &components[field.component_index].data;
	params := cast(^[]animation.Animation_Param)get_component_field_data(components[:], field);
	
	if selected_metadata_index < 0
	{
		anim_param_list := objects.Anim_Param_List_Metadata{make([]objects.Anim_Param_Metadata, 256), 0};
		new_metadata: objects.Type_Specific_Metadata = to_type_specific_metadata(field.type_id, anim_param_list);
		component_data.metadata[component_data.metadata_count] = new_metadata;
		component_data.metadata_offsets[component_data.metadata_count] = field.offset_in_component;
		component_data.metadata_types[component_data.metadata_count] = field.type_id;
		selected_metadata_index = component_data.metadata_count;
		component_data.metadata_count += 1;
	}

	metadata_info, ok := component_data.metadata[selected_metadata_index].(objects.Type_Specific_Metadata);

	if !ok || metadata_info.field_type_id != typeid_of(objects.Anim_Param_List_Metadata)
	{
		anim_param_list := objects.Anim_Param_List_Metadata{make([]objects.Anim_Param_Metadata, 256), 0};
		new_metadata: objects.Type_Specific_Metadata = to_type_specific_metadata(field.type_id, anim_param_list);
		component_data.metadata[component_data.metadata_count] = new_metadata;
		metadata_info = component_data.metadata[selected_metadata_index].(objects.Type_Specific_Metadata);
	}

	anim_metadata_info := get_type_specific_metadata(objects.Anim_Param_List_Metadata, &metadata_info);

	for param, index in params
	{
		imgui.push_id(i32(index));
		imgui.input_string("name", &param.name);
		imgui.next_column();

		selected_component_id: string = "nil";
		anim_param_data := &anim_metadata_info.anim_params[index];

		if anim_param_data.component_index > 0
		{
			selected_component_id = components[anim_param_data.component_index - 1].id;
		}

		if imgui.begin_combo("Component", selected_component_id, .PopupAlignLeft)
		{
			for component, index in components
			{
				if imgui.tree_node(component.id)
				{
					component_type := prefab_tables.tables[component.table_index].table.type_id;
					for field in find_component_fields_of_type(component_type, typeid_of(f32))
					{
						is_selected_component := index == anim_param_data.component_index - 1;
						is_selected_field := field.offset == uintptr(anim_param_data.offset_in_component);
						if imgui.selectable(field.name, is_selected_component && is_selected_field)
						{
							anim_param_data.component_index = index + 1;
							anim_param_data.offset_in_component = int(field.offset);
						}

					}
					imgui.tree_pop();
				}
			}
			if imgui.selectable("nil", anim_param_data.component_index == 0)
			{
				anim_param_data.component_index = 0;
			}
			imgui.end_combo();
		}
		if anim_param_data.component_index > 0
		{
			selected_field_name := "nil";
			selectable_fields: [dynamic]Prefab_Field;
			selected_component_index := anim_param_data.component_index-1;
			selected_component_type := prefab_tables.tables[selected_component_index].table.type_id;


			for component_field in find_component_fields_of_type(selected_component_type, typeid_of(f32))
			{
				if int(component_field.offset) == anim_param_data.offset_in_component 
				{
					if int(component_field.offset) == anim_param_data.offset_in_component
					{
						selected_field_name = component_field.name;
					}
				}
			}
		}
		imgui.next_column();
		imgui.pop_id();
	}
	if imgui.button("+")
	{
		copy := make([]animation.Animation_Param, len(params) + 1, context.allocator);
		for param, index in params do copy[index] = param;
		delete(params^);
		params^ = copy;
		params[len(params)-1].type_id = typeid_of(f32);
	}
}

find_struct_fields_of_type :: proc(type_info: runtime.Type_Info_Struct, expected_type_id: typeid) -> []reflect.Struct_Field
{
	result := make([dynamic]reflect.Struct_Field, context.temp_allocator);
	using type_info;
	for i in 0..<len(types)
	{
		if types[i].id == expected_type_id 
		{
			append(&result, reflect.Struct_Field{names[i], types[i].id, {}, offsets[i], false});
		}
	}
	return result[:];
}

find_component_fields_of_type :: proc(struct_type_id: typeid, expected_type_id: typeid) -> []reflect.Struct_Field
{
	#partial switch variant in type_info_of(struct_type_id).variant
	{
		case runtime.Type_Info_Named:
			return find_struct_fields_of_type(variant.base.variant.(runtime.Type_Info_Struct), expected_type_id);

		case runtime.Type_Info_Struct:
			return find_struct_fields_of_type(variant, expected_type_id);
	}
	return make([]reflect.Struct_Field, 0);
}

find_components_fields_of_type :: proc(prefab_tables: ^objects.Named_Table_List, components: []objects.Component_Model, expected_type_id: typeid) -> []Prefab_Field
{
	result := make([dynamic]Prefab_Field, context.temp_allocator);
	for component, component_index in components
	{
		component_type_id := prefab_tables.tables[component.table_index].table.type_id;
		#partial switch variant in type_info_of(component_type_id).variant
		{
			case runtime.Type_Info_Named:
				fields := find_struct_fields_of_type(variant.base.variant.(runtime.Type_Info_Struct), expected_type_id);
				for field in fields
				{
					field_name := fmt.tprintf("%s/%s", component.id, field.name);
					append(&result, Prefab_Field{{field_name, field.offset, expected_type_id}, component_index});
				}

			case runtime.Type_Info_Struct:
				fields := find_struct_fields_of_type(variant, expected_type_id);
				for field in fields
				{
					field_name := fmt.tprintf("%s/%s", component.id, field.name);
					append(&result, Prefab_Field{{field_name, field.offset, expected_type_id}, component_index});
				}
		}
	}
	return result[:];
}

sprite_editor_callback :: proc(using prefab: Editor_Prefab, field: Prefab_Field, scene_database: ^container.Database)
{
	metadata_index := get_component_field_metadata_index(components[:], field);
	component := components[field.component_index];
	display_sprite: render.Sprite_Handle;
	sprite_asset: render.Sprite_Asset;
	sprite_database := container.database_get(scene_database, render.Sprite_Database);

	if metadata_index >= 0
	{
		metadata, ok := component.data.metadata[metadata_index].(objects.Type_Specific_Metadata);
		assert(ok);
		sprite_metadata := get_type_specific_metadata(render.Sprite_Asset, &metadata);
		sprite_handle, sprite_found := render.get_or_load_sprite(sprite_database, transmute(render.Sprite_Asset)(sprite_metadata^));
		if !sprite_found
		{
			log.info("Could not load sprite", transmute(render.Sprite_Asset)(sprite_metadata^));
			assert(false);
		}
		if sprite_found
		{
			if sprite_widget(sprite_database, sprite_handle)
			{
				open_sprite_selector("sprite_selector", "resources/textures");
				imgui.open_popup("sprite_selector");
			}
		}
	}
	else
	{
		search_config := File_Search_Config{
			start_folder = "resources/textures",
			filter_type = .Show_With_Ext,
			extensions = available_sprite_extensions[:],
		};
		if imgui.button("nil", {100, 100})
		{
			open_sprite_selector("sprite_selector", "resources/textures");
			imgui.open_popup("sprite_selector");
		}
		center := [2]f32{imgui.get_io().display_size.x * 0.5, imgui.get_io().display_size.y * 0.5};
		imgui.set_next_window_pos(center, .Appearing, [2]f32{0.5, 0.5});
		imgui.set_next_window_size_constraints({500, 500}, {});
		
	}
	if imgui.begin_popup_modal("sprite_selector", nil, .AlwaysAutoResize)
	{
		result, search_state := sprite_selector_popup_content(sprite_database, "sprite_selector");
		imgui.end_popup();
		#partial switch search_state
		{
			case .Found:
			{
				sprite_metadata := render.Sprite_Asset{strings.clone(result.path), strings.clone(result.sprite_id)};
				set_component_field_metadata(components[:], field, to_type_specific_metadata(field.type_id, sprite_metadata));
			}
		}
	}
}

transform_editor_callback :: proc(using prefab: Editor_Prefab, field: Prefab_Field, scene_database: ^container.Database)
{
	component := components[field.component_index];
	transform := get_component_field_data(components[:], field, gameplay.Transform);
	parent_field := field;
	parent_field.offset_in_component = reflect.struct_field_by_name(gameplay.Transform, "parent").offset;
	metadata_index := get_component_field_metadata_index(components[:], field);
	selected_parent_name: string;
	if metadata_index >= 0
	{
		switch metadata_type in component.data.metadata[metadata_index]
		{
			case objects.Ref_Metadata:
				selected_parent_name = components[metadata_type.component_index].id;
			case objects.Input_Metadata:
				selected_parent_name = inputs[metadata_type.input_index].name;
			case objects.Type_Specific_Metadata:
				panic("Error : Type_Specific_Metadata in Transform");
		}
	}
	if imgui.begin_combo("Parent", selected_parent_name, .PopupAlignLeft)
	{
		
		imgui.end_combo();
	}

}