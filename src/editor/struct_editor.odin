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

Struct_Editor_Delegate :: proc(data: rawptr, scene_database: ^container.Database) -> bool;
Editor_Delegate_Map :: map[typeid]Struct_Editor_Delegate;

default_struct_editor_delegates: Editor_Delegate_Map =
{
	typeid_of(render.Sprite_Handle) = sprite_struct_editor
};

struct_editor :: proc(data: rawptr, type_id: typeid, scene_database: ^container.Database, delegates: Editor_Delegate_Map = default_struct_editor_delegates) -> bool
{
	type_info := type_info_of(type_id);
	return struct_editor_rec(data, type_info, delegates, scene_database);
}

struct_editor_rec :: proc(data: rawptr, type_info: ^runtime.Type_Info, delegates: Editor_Delegate_Map, scene_database: ^container.Database) -> bool
{
	if type_info.id in delegates
	{
		return delegates[type_info.id](data, scene_database);
	}
	#partial switch variant in type_info.variant
	{
		case runtime.Type_Info_Struct:
			result: bool = false;
			for i in 0..<len(variant.names)
			{
				imgui.push_id(variant.names[i]);
				result |= struct_editor_rec(rawptr(uintptr(data) + variant.offsets[i]), variant.types[i], delegates, scene_database);
				imgui.pop_id();
			}

		case runtime.Type_Info_Named:
			return struct_editor_rec(data, variant.base, delegates, scene_database);
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
				result |= struct_editor_rec(rawptr(uintptr(data) + uintptr(i * variant.elem_size)), variant.elem, delegates, scene_database);
				imgui.pop_id();
			}


	}
	return false;
}

sprite_widget :: proc(using db: ^render.Sprite_Database, sprite: render.Sprite_Handle) -> bool
{
	sprite_data := container.handle_get(sprite);
	clip := sprite_data.clip;
	texture_handle := sprite_data.texture;
	texture_data := container.handle_get(texture_handle);
	texture_size : [2]f32 = {f32(texture_data.size.x), f32(texture_data.size.y)};
	max_size := max(clip.size.x, clip.size.y);
	imgui.begin_group();
	img_size : [2]f32 = {100 * clip.size.x / max_size, 100 * clip.size.y / max_size};
	imgui.set_cursor_pos_x(imgui.get_cursor_pos_x() + 50 - img_size.x / 2);  
	result := imgui.image_button(imgui.Texture_ID(uintptr(texture_data.texture_id)), img_size, clip.pos, clip.pos + clip.size);
	text_size: [2]f32;
	sprite_id := sprite_data.id;
	imgui.calc_text_size(&text_size, sprite_id);
	imgui.set_cursor_pos_x(imgui.get_cursor_pos_x() + 50 - text_size.x / 2);
	imgui.text_unformatted(sprite_id);
	imgui.end_group();
	return result;
}

sprite_struct_editor :: proc(data: rawptr, scene_database: ^container.Database) -> bool
{
	sprite_database := container.database_get(scene_database, render.Sprite_Database);
	sprite := cast(^render.Sprite_Handle)data;
	log.info(sprite);
	if sprite.id == 0
	{
		imgui.text("nil sprite");
	}
	else
	{
		sprite_widget(sprite_database, sprite^);
	}
	imgui.same_line();

	selected_sprite, search_state := sprite_selector(sprite_database, "sprite_selector", "resources/textures");
	#partial switch search_state
	{
		case .Found:
		{
			sprite^ = selected_sprite;
		}
	}
	return false;
}