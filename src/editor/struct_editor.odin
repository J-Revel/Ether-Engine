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

sprite_widget :: proc(using scene: ^gameplay.Scene, sprite: render.Sprite_Handle)
{
	sprite_data := container.handle_get(sprite);
		clip := sprite_data.clip;
		imgui.text_unformatted(sprite_data.id);
		imgui.text_unformatted(fmt.tprintf("(%f, %f), (%f, %f)", clip.pos.x, clip.pos.y, clip.size.x, clip.size.y));
		texture_handle := sprite_data.texture;
		texture_data := container.handle_get(texture_handle);
		texture_size : [2]f32 = {f32(texture_data.size.x), f32(texture_data.size.y)};
		max_size := max(clip.size.x, clip.size.y);
		imgui.button("", {100, 100});
		imgui.image(imgui.Texture_ID(uintptr(texture_data.texture_id)), {100 * clip.size.x / max_size, 100 * clip.size.y / max_size}, clip.pos, clip.pos + clip.size);
}

sprite_struct_editor :: proc(using scene: ^gameplay.Scene, data: rawptr) -> bool
{
	sprite := cast(^render.Sprite_Handle)data;
	if sprite.id == 0
	{
		imgui.text("nil sprite");
	}
	else
	{
		sprite_widget(scene, sprite^);
	}
	imgui.same_line();

	selected_sprite, search_state := sprite_selector(scene, "sprite_selector", "resources/textures");
	#partial switch search_state
	{
		case .Found:
		{
			sprite^ = selected_sprite;
		}
	}
	return false;
}