package gameplay

import "../render"
import "core:log"
import "../input"
import "core:strconv"

import imgui "../../libs/imgui"
import "core:math/rand"
import "core:math"
import "core:math/linalg"

import sdl "shared:odin-sdl2"

import container "../container"

import os "core:os"

import json "core:encoding/json"

import gl "shared:odin-gl";

import "../animation"

import "../objects"

import "core:reflect"

import "../ui"

Scene :: struct
{
	camera: render.Camera,
	prefab_tables: objects.Named_Table_List,
    color_renderer: render.Color_Render_System,
    sprite_renderer: render.Sprite_Render_System,
    transforms: objects.Transform_Table,
    sprite_components: container.Table(Sprite_Component),
    using sprite_database: render.Sprite_Database,
    using animation_database: animation.Animation_Database,

    scene_database: container.Database,
}

init_empty_scene :: proc(using scene: ^Scene)
{
	container.table_init(&textures, 100);
	container.table_init(&sprites, 200);
	objects.table_database_add_init(&prefab_tables, "transform", &transforms, 10000);
	objects.table_database_add_init(&prefab_tables, "sprite_component", &sprite_components, 500);
	
	animation.init_animation_database(&prefab_tables, &animation_database);

	container.database_add(&scene_database, &sprite_database);
	container.database_add(&scene_database, &animation_database);

	render.init_sprite_renderer(&sprite_renderer.render_state);
	render.init_color_renderer(&color_renderer.render_state);
	
	camera.zoom = 1;
}

test_animation_keyframes : [4]animation.Keyframe(f32) = {animation.Keyframe(f32){0, 0}, animation.Keyframe(f32){0.5, 1}, animation.Keyframe(f32){0.75, 0.5}, animation.Keyframe(f32){1, 1} };
init_main_scene :: proc(using scene: ^Scene)
{
	using container;
	init_empty_scene(scene);


	render.load_sprites_from_file("test.sprites", &textures, &sprites);

	spaceship_sprite, sprite_found := render.get_sprite_any_texture(&sprite_database, "spaceship");
	spaceship_sprite2, sprite2_found := render.get_sprite_any_texture(&sprite_database, "spaceship_2");
	load_metadata_dispatcher: objects.Load_Metadata_Dispatcher;

	prefab_instance, ok := objects.load_prefab("config/prefabs/buildings/ship.prefab", &prefab_tables, &load_metadata_dispatcher);
	test_input: map[string]any;
	test_input["sprite"] = spaceship_sprite;
	test_input["pos"] = [2]f32{10, 50};
	test_input["scale"] = f32(0.1);

	prefab_instance_components, _ := objects.prefab_instantiate(&prefab_tables, &prefab_instance, test_input, {});
	it := container.table_iterator(&transforms);
	for transform in container.table_iterate(&it)
	{
		log.info(transform);
	}

	test_input["sprite"] = spaceship_sprite2;
	test_input["pos"] = [2]f32{-350, 0};
	test_input["scale"] = f32(0.5);

	objects.prefab_instantiate(&prefab_tables, &prefab_instance, test_input, {});

	using animation;

	test_curve: Animation_Curve(f32);
	test_curve.keyframes = test_animation_keyframes[:];
	test_curve_handle, _ := table_add(&animation_curves, test_curve);

	float_curves := make([]Named_Float_Curve, 1, context.allocator);
	float_curves[0] = {"test", test_curve_handle};
	test_animation: Animation_Config = {
		duration = 3, 
		float_curves = float_curves
	};

	test_animation_handle, animation_added := table_add(&animation_configs, test_animation);
	log.info("Animation added", animation_added);
	test_anim_param : Animation_Param = {name="test", type_id=typeid_of(f32)};
	test_anim_param.offset = reflect.struct_field_by_name(typeid_of(objects.Transform), "scale").offset;
	for prefab_component in prefab_instance_components
	{
		log.info(prefab_component);
		if prefab_component.name == "main_transform"
		{
			test_anim_param.handle = prefab_component.value;
		}
	}
	params_array := make([]Animation_Param, 1, context.allocator);
	params_array[0] = test_anim_param;

	log.info("test anim param", test_anim_param);
	animation_player := Animation_Player { 
		animation = test_animation_handle, 
		params = params_array,
	};
	table_add(&animation_players, animation_player);
}

time : f32 = 0;
ui_ctx: ui.UI_Context;

update_and_render :: proc(using scene: ^Scene, delta_time: f32, input_state: ^input.State, viewport: render.Viewport)
{

	animation.update_animations(&animation_players, delta_time);

	// spaceship_sprite, sprite_found := render.get_sprite_any_texture(&sprite_database, "spaceship");
	

	// spaceship_sprite_data := container.handle_get(spaceship_sprite);
	//render.render_sprite(&scene.sprite_renderer.buffer, spaceship_sprite_data, {0, 0}, render.Color{1, 1, 1, 1}, 100);
	render_sprite_components(&scene.sprite_renderer, &sprite_components);

	ui.reset_ctx(&ui_ctx, input_state, linalg.to_f32(viewport.size));
	
	//ui.rect(&draw_list, {0, 0}, {200, 200}, {1, 1, 1, 1});

	
	if ui.layout_button("test", {100, 100}, &ui_ctx)
	{
		log.info("BUTTON1");
	}

	ui.vsplit_layout(0.3, &ui_ctx);

		if ui.layout_button("test", {100, 100}, &ui_ctx)
		{
			log.info("BUTTON2");
		}
	ui.next_layout(&ui_ctx);
		if ui.layout_button("test", {100, 100}, &ui_ctx)
		{
			log.info("BUTTON3");
		}
		if ui.layout_button("test", {100, 100}, &ui_ctx)
		{
			log.info("BUTTON2");
		}
		if ui.layout_button("test", {100, 100}, &ui_ctx)
		{
			log.info("BUTTON3");
		}
}

do_render :: proc(using scene: ^Scene, viewport: render.Viewport)
{
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
	gl.Viewport(i32(viewport.top_left.x), i32(viewport.top_left.y), i32(viewport.size.x), i32(viewport.size.y));

	ui.render_draw_list(&ui_ctx.draw_list, &scene.color_renderer);

	//render_wave({test_arc}, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	// render.render_buffer_content(&color_renderer, &camera);
	// texture_id := container.table_get(&textures, spaceship_sprite_data.texture).texture_id;
	
	render.render_sprite_buffer_content(&scene.sprite_renderer, &camera, viewport);

	ui_camera := render.Camera{
		world_pos = linalg.to_f32(viewport.size / 2),
		zoom = 1,
	};
    render.render_buffer_content(&scene.color_renderer, &ui_camera, viewport);
    render.clear_render_buffer(&color_renderer.buffer);
    render.clear_sprite_render_buffer(&scene.sprite_renderer);
}