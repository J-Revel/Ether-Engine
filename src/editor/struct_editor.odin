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

handle_editor_callback :: proc(using editor_state: ^Prefab_Editor_State, field: Component_Model_Field)
{
	tables := container.db_get_tables_of_type(&scene.db, field.type_id);
	field_data := get_component_field_data(components[:], field);
	current_value := (cast(^container.Raw_Handle)field_data);

	selected_ref_index, selected_ref_target := get_component_ref_index(components[:], field);
	
	selected_input_index := get_component_input_index(components[:], field);
	current_value_name := "";
	selected_input_name : string;
	if selected_input_index >= 0 
	{
		component := editor_state.components[field.component_index];
		input_index := component.data.inputs[selected_input_index].input_index;
		selected_input_name = inputs[input_index].name;
		current_value_name = fmt.tprintf("(input)%s", selected_input_name);
	}
	else if selected_ref_index >= 0
	{
		current_value_name = fmt.tprintf("(ref)%s", components[selected_ref_target].id);
	}

	display_value := current_value_name;

	struct_field := reflect.Struct_Field
	{
		name = field.name, 
		type = field.type_id, 
		offset = field.offset_in_component
	};
	imgui.push_id("handles");
	if input_ref_combo("", field, editor_state) do record_history_step(editor_state);
	imgui.pop_id();
}

struct_field_editor_callback :: proc(using editor_state: ^Prefab_Editor_State, field: Component_Model_Field)
{
	
}

animation_player_editor_callback :: proc(using editor_state: ^Prefab_Editor_State, field: Component_Model_Field)
{
	params := cast(^[]animation.Animation_Param)get_component_field_data(components[:], field);
	for param, index in params
	{
		imgui.push_id(i32(index));
		imgui.columns(2);
		imgui.input_string("name", &param.name);
		imgui.next_column();
		if imgui.begin_combo("value", "Display Value", .PopupAlignLeft)
		{
			fields := find_component_fields_of_type(&scene.db, components[:], param.type_id);
			imgui.text(fmt.tprintf("%d", len(fields)));
			for component_field in fields
			{
				if imgui.selectable(component_field.name, false)
				{
					//param.handle = field.
				}
			}
			imgui.end_combo();
		}
		imgui.next_column();
		imgui.columns(1);
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

find_component_fields_of_type :: proc(db: ^container.Database, components: []objects.Component_Model, expected_type_id: typeid) -> []Component_Model_Field
{
	result := make([dynamic]Component_Model_Field, context.temp_allocator);
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
					append(&result, Component_Model_Field{field_name, component_index, field.offset, expected_type_id});
				}

			case runtime.Type_Info_Struct:
				fields := find_struct_fields_of_type(variant, expected_type_id);
				for field in fields
				{
					field_name := fmt.tprintf("%s/%s", component.id, field.name);
					append(&result, Component_Model_Field{field_name, component_index, field.offset, expected_type_id});
				}
		}
	}
	return result[:];
}