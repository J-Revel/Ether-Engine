package editor

import imgui "../imgui";
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

handle_editor_callback :: proc(using editor_state: ^Prefab_Editor_State, field: Prefab_Field)
{
	metadata_index := get_component_field_metadata_index(components[:], field);
	current_value_name := "nil";
	component := editor_state.components[field.component_index];
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

			case objects.Anim_Param_List_Metadata:

		}
	}
	imgui.text(current_value_name);
	// tables := container.db_get_tables_of_type(&scene.db, field.type_id);
	// field_data := get_component_field_data(components[:], field);
	// current_value := (cast(^container.Raw_Handle)field_data);


	// current_value_name := "";
	// selected_input_name : string;

	// component := editor_state.components[field.component_index];

	// display_value := current_value_name;

	// struct_field := reflect.Struct_Field
	// {
	// 	name = field.name, 
	// 	type = field.type_id, 
	// 	offset = field.offset_in_component
	// };
	// imgui.push_id("handles");
	// if input_ref_combo("", field, editor_state) do record_history_step(editor_state);
	// imgui.pop_id();
}

animation_player_editor_callback :: proc(using editor_state: ^Prefab_Editor_State, field: Prefab_Field)
{
	selected_metadata_index := get_component_field_metadata_index(components[:], field);
	component_data := &components[field.component_index].data;
	params := cast(^[]animation.Animation_Param)get_component_field_data(components[:], field);
	
	if selected_metadata_index < 0
	{
		anim_param_list := objects.Anim_Param_List_Metadata{make([]objects.Anim_Param_Metadata, 256), 0};
		component_data.metadata[component_data.metadata_count] = anim_param_list;
		component_data.metadata_offsets[component_data.metadata_count] = field.offset_in_component;
		component_data.metadata_types[component_data.metadata_count] = field.type_id;
		selected_metadata_index = component_data.metadata_count;
		component_data.metadata_count += 1;
	}

	metadata_info, ok := component_data.metadata[selected_metadata_index].(objects.Anim_Param_List_Metadata);

	if !ok
	{
		anim_param_list := objects.Anim_Param_List_Metadata{make([]objects.Anim_Param_Metadata, 256), 0};
		component_data.metadata[component_data.metadata_count] = anim_param_list;
		metadata_info = component_data.metadata[selected_metadata_index].(objects.Anim_Param_List_Metadata);
	}

	for param, index in params
	{
		imgui.push_id(i32(index));
		imgui.input_string("name", &param.name);
		imgui.next_column();

		selected_component_id: string = "nil";
		anim_param_data := &metadata_info.anim_params[index];

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
					component_type := scene.db.tables[component.table_index].table.type_id;
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
			selected_component_type := scene.db.tables[selected_component_index].table.type_id;


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
			append(&result, reflect.Struct_Field{names[i], types[i].id, {}, offsets[i]});
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

find_components_fields_of_type :: proc(db: ^container.Database, components: []objects.Component_Model, expected_type_id: typeid) -> []Prefab_Field
{
	result := make([dynamic]Prefab_Field, context.temp_allocator);
	for component, component_index in components
	{
		component_type_id := db.tables[component.table_index].table.type_id;
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