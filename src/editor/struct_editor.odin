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

Struct_Editor_Delegate :: proc(scene: ^gameplay.Scene, data: rawptr) -> bool;
Editor_Delegate_Map :: map[typeid]Struct_Editor_Delegate;

default_struct_editor_delegates: Editor_Delegate_Map =
{
	typeid_of(render.Sprite_Handle) = sprite_struct_editor
};

struct_editor :: proc(using scene: ^gameplay.Scene, data: rawptr, type_id: typeid, delegates: Editor_Delegate_Map = default_struct_editor_delegates) -> bool
{
	type_info := type_info_of(type_id);
	return struct_editor_rec(scene, data, type_info, delegates);
}

struct_editor_rec :: proc(using scene: ^gameplay.Scene, data: rawptr, type_info: ^runtime.Type_Info, delegates: Editor_Delegate_Map) -> bool
{
	if type_info.id in delegates
	{
		return delegates[type_info.id](scene, data);
	}
	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			result: bool = false;
			for i in 0..<len(variant.names)
			{
				imgui.push_id(variant.names[i]);
				result |= struct_editor_rec(scene, rawptr(uintptr(data) + variant.offsets[i]), variant.types[i], delegates);
				imgui.pop_id();
			}

		case runtime.Type_Info_Named:
			return struct_editor_rec(scene, data, variant.base, delegates);
		case runtime.Type_Info_Float:
			imgui.input_float("", transmute(^f32)data);
		case runtime.Type_Info_Integer:
			if variant.signed
			{
				value := (transmute(^int)data);
				cast_value := i32(value^);
				if imgui.input_int("", &cast_value)
				{
					value^ = int(cast_value);
					return true;
				}
				return false;
			}
			else
			{
				value := transmute(^uint)data;
				cast_value := i32(value^);
				if imgui.input_int("", &cast_value)
				{
					value^ = uint(cast_value);
					return true;
				}
				return true;
			}
			return imgui.input_float("", transmute(^f32)data);
		case runtime.Type_Info_String:
			return imgui.input_string("", transmute(^string)data);
		case runtime.Type_Info_Boolean:
			return imgui.checkbox("", transmute(^bool)data);
		case runtime.Type_Info_Array:
			result: bool = false;
			for i in 0..<variant.count
			{
				imgui.push_id(i32(i));
				result |= struct_editor_rec(scene, rawptr(uintptr(data) + uintptr(i * variant.elem_size)), variant.elem, delegates);
				imgui.pop_id();
			}


	}
	return false;
}

sprite_struct_editor :: proc(using scene: ^gameplay.Scene, data: rawptr) -> bool
{
	sprite: render.Sprite_Handle;
	if sprite.id == 0
	{
		imgui.text("nil sprite");
	}
	else
	{
		imgui.text("Some sprite");
	}
	imgui.same_line();

	sprite_selector(scene, "sprite_selector", "resources/textures");
	return false;
}