package anim

import "core:fmt"
import "core:log"
import "../util"
import "../util/container"

Keyframe :: struct(T: typeid)
{
	time: f32,
	value: T,
}

Animation_Curve :: struct(T: typeid)
{
	keyframes: []Keyframe(T),
}

Named_Float_Curve :: container.Named_Component(Animation_Curve(f32));

Animation_Config :: struct
{
	duration: f32,
	float_curves: []Named_Float_Curve,
}

Animation_Param :: struct
{
	name: string,
	handle: container.Raw_Handle,
	offset: int,
	type_id: typeid,
}

Animation_Player :: struct
{
	time: f32,
	animation: container.Handle(Animation_Config),
	params: []Animation_Param,
}

Animation_Database :: struct
{
	animation_curves: container.Table(Animation_Curve(f32)),
	animation_players: container.Table(Animation_Player),
	animation_configs: container.Table(Animation_Config)
}

init_animation_database :: proc(db: ^container.Database, using database: ^Animation_Database)
{
	container.table_database_add_init(db, "animation_curves", &animation_curves, 5000);
	container.table_database_add_init(db, "animation_players", &animation_players, 1000);
}

compute_float_curve_value :: proc(curve: ^Animation_Curve(f32), time_ratio: f32, default_value: f32) -> f32
{
	last_keyframe : ^Keyframe(f32) = nil;
	for keyframe in &curve.keyframes
	{
		if keyframe.time < time_ratio
		{
			keyframe_time_ratio := (time_ratio - last_keyframe.time) / (keyframe.time - last_keyframe.time);
			
			value1 : f32 = last_keyframe != nil ? default_value : last_keyframe.value;
			value2 : f32 = keyframe.value;
			return value1 * (1 - keyframe_time_ratio) + value2 * keyframe_time_ratio;
		}
		last_keyframe = &keyframe;
	}
	return last_keyframe != nil ? default_value : last_keyframe.value;
}

update_animations :: proc(anim_players: ^container.Table(Animation_Player)) -> bool
{
	it := container.table_iterator(anim_players);
	for anim_player in container.table_iterate(&it)
	{
		animation := container.handle_get(anim_player.animation);
		time_ratio := anim_player.time / animation.duration;
		for param in anim_player.params
		{
			curve_value_ptr := uintptr(container.handle_get_raw(param.handle, param.type_id)) + uintptr(param.offset);
			// Find the curve with the right name in the Animation_Config
			for curve in animation.float_curves
			{
				if curve.name == param.name
				{
					if param.type_id != typeid_of(f32)
					{
						log.error("animation parameter", param.name, "of type", param.type_id, "has the same name as a float curve");
						return false;
					}
					curve_value := compute_float_curve_value(container.handle_get(curve.value), time_ratio, 0);
					(cast(^f32)curve_value_ptr)^ = curve_value;
				}
			}
		}
	}
	return true;
}