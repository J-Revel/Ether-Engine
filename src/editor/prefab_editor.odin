package editor

import imgui "../imgui";
import "core:log"
import "core:strings"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:reflect"

import "../geometry"
import "../gameplay"
import "../render"
import "../container"

init_prefab_editor :: proc(using editor_state: ^Prefab_Editor_State)
{
	gameplay.init_empty_scene(&scene);
	editor_type_callbacks[typeid_of(container.Handle(render.Texture))] = texture_handle_editor_callback;
	editor_type_callbacks[typeid_of(container.Handle(render.Sprite))] = sprite_handle_editor_callback;
	editor_type_callbacks[typeid_of(container.Handle(gameplay.Transform))] = transform_handle_editor_callback;
}

texture_handle_editor_callback :: proc(element: any)
{
	assert(element.id == typeid_of(container.Handle(render.Texture)));
	imgui.button("TEXTURE_HANDLE");
}

sprite_handle_editor_callback :: proc(element: any)
{
	assert(element.id == typeid_of(container.Handle(render.Sprite)));
	imgui.button("SPRITE_HANDLE");
}

transform_handle_editor_callback :: proc(element: any)
{
	assert(element.id == typeid_of(container.Handle(gameplay.Transform)));
	imgui.button("TRANSFORM_HANDLE");
}

component_editor :: proc
{
	component_editor_root,
	component_editor_child
};

component_editor_root :: proc(component_data: any, editor_type_callbacks: map[typeid]Editor_Type_Callback)
{
	callback, callback_found := editor_type_callbacks[component_data.id];
	if callback_found
	{
		callback(component_data);
		return;
	}
	
                	
	type_info := type_info_of(component_data.id);
    #partial switch variant in type_info.variant
    {
        case runtime.Type_Info_Struct:
            structInfo, ok := type_info.variant.(runtime.Type_Info_Struct);
            for _, i in structInfo.names
            {
                imgui.text_unformatted(fmt.tprintf("%s : ", structInfo.names[i]));
                imgui.same_line();
                imgui.begin_group();
                imgui.push_id(structInfo.names[i]);
                field := rawptr(uintptr(component_data.data) + structInfo.offsets[i]);
        		component_editor_child(structInfo.names[i], {field, structInfo.types[i].id}, editor_type_callbacks);
                imgui.pop_id();
                imgui.end_group();
            }
        case runtime.Type_Info_Named:
            component_editor_root({component_data.data, variant.base.id}, editor_type_callbacks);
	}
}

component_editor_child :: proc(base_name: string, component_data: any, editor_type_callbacks: map[typeid]Editor_Type_Callback)
{
	callback, callback_found := editor_type_callbacks[component_data.id];
	if callback_found
	{
		callback(component_data);
		return;
	}
	
                	
	type_info := type_info_of(component_data.id);
    #partial switch variant in type_info.variant
    {
        case runtime.Type_Info_Struct:
        	if imgui.tree_node(base_name)
		    {
	            structInfo, ok := type_info.variant.(runtime.Type_Info_Struct);
	            for _, i in structInfo.names
	            {
	                imgui.push_id(structInfo.names[i]);
	                field := rawptr(uintptr(component_data.data) + structInfo.offsets[i]);
	        		component_editor_child(structInfo.names[i], {field, structInfo.types[i].id}, editor_type_callbacks);
	                	
	                imgui.pop_id();
	            }
	            imgui.tree_pop();
	        }
        case runtime.Type_Info_Named:
            component_editor_child(variant.name, {component_data.data, variant.base.id}, editor_type_callbacks);
        case runtime.Type_Info_Integer:
            imgui.input_int(base_name, cast(^i32) component_data.data);
        case runtime.Type_Info_Float:
            imgui.input_float(base_name, cast(^f32) component_data.data);
        case runtime.Type_Info_String:

        	return;
        case runtime.Type_Info_Array:
    		imgui.columns(i32(variant.count));
        	for i in 0..<variant.count
        	{
                imgui.push_id(fmt.tprintf("element_%d", i));
                char := 'x' + i;
    			txt := fmt.tprintf("%c", char);
        		component_editor_child(txt, {rawptr(uintptr(component_data.data) + uintptr(variant.elem_size * i)), variant.elem.id}, editor_type_callbacks);
        		imgui.pop_id();
        		imgui.next_column();
        	}
    		imgui.columns(1);
	}
}

update_prefab_editor :: proc(using editor_state: ^Prefab_Editor_State)
{
	if new_component_data == nil
	{
		type_info := type_info_of(scene.db[0].table.type_id);
		new_component_data = mem.alloc(type_info.size, type_info.align);
	}
	imgui.columns(2);
	if imgui.begin_combo("new component type", scene.db[new_component_index].name, .PopupAlignLeft)
	{
		for named_table, index in scene.db
		{
			if imgui.selectable(named_table.name, index == new_component_index)
			{
				new_component_index = index;
				mem.free(new_component_data);
				type_info := type_info_of(named_table.table.type_id);
				new_component_data = mem.alloc(type_info.size, type_info.align);
			}
		}
		imgui.end_combo();
	}
	imgui.next_column();
	if(imgui.button("add"))
	{

	}
	imgui.next_column();
	imgui.columns(1);
	component_editor(any{new_component_data, runtime.typeid_base(scene.db[new_component_index].table.type_id)}, editor_type_callbacks);
}