package gameplay

import "../render"
import "core:log"
import "../input"
import "core:strconv"

import imgui "../imgui"
import "core:math/rand"
import "core:math"

import sdl "shared:odin-sdl2"

import container "../util/container"

import os "core:os"

import json "core:encoding/json"

import gl "shared:odin-gl";

spaceship_sprite : render.Sprite;

Scene :: struct
{
	camera: render.Camera,
	tool_state: Tool_State,
	buildings: container.Table(Building),
	loading_buildings: container.Table(Loading_Building),
	wave_emitters: container.Table(Wave_Emitter),
	planets: container.Table(Planet),
    arcs: container.Table(Wave_Arc),
    db: container.Database,
    color_renderer: render.Color_Render_System,
    sprite_renderer: render.Sprite_Render_System,
    textures: container.Table(render.Texture),
}

init_scene :: proc(using scene: ^Scene)
{

	container.table_init(&buildings, 1000);
	container.table_init(&loading_buildings, 1000);
	container.table_init(&planets, 1000);
	container.table_init(&arcs, 1000);
	container.table_init(&wave_emitters, 100);
	container.table_init(&textures, 100);
	container.table_database_add(&db, "building", &buildings);
	container.table_database_add(&db, "loading_building", &loading_buildings);
	container.table_database_add(&db, "planet", &planets);
	container.table_database_add(&db, "arc", &arcs);
	container.table_database_add(&db, "wave_emitter", &wave_emitters);
	prefab_instance, ok := container.load_prefab("config/prefabs/buildings/building_1.prefab", scene.db);
	log.info(prefab_instance, ok);
	camera.zoom = 1;
	for i := 0; i < 10; i+=1
	{
		p : Planet;
		generate(&p, rand.float32() * 200 + 100, 10);
		p.pos = [2]f32{800 * cast(f32)i, 0};
		container.table_add(&planets, p);
	}
	test_input: map[string]any;
	planet: ^Planet = container.table_get(&planets, container.Handle(Planet){1, &planets});
	test_input["planet"] = planet;
	for i := 0; i<8; i += 1
	{
		test_input["angle"] = f32(math.PI / 4.0) * f32(i);
		container.prefab_instantiate(&db, &prefab_instance, test_input);
	}
	tool_state = Basic_Tool_State{};

	render.init_sprite_renderer(&sprite_renderer.render_state);
	render.init_color_renderer(&color_renderer.render_state);
	spaceship_texture : render.Texture = render.load_texture("resources/textures/spaceship.png");
	texture_handle, ok_texture_add := container.table_add(&scene.textures, spaceship_texture);
	spaceship_sprite = render.Sprite{texture_handle, {0.5, 0.5}, {}};
}

time : f32 = 0;

update_and_render :: proc(using scene: ^Scene, deltaTime: f32, screen_size: [2]f32, input_state: ^input.State)
{

	color_renderer.screen_size = screen_size;
	sprite_renderer.screen_size = screen_size;
	worldMousePos := render.camera_to_world(&scene.camera, &color_renderer, input_state.mouse_pos);
    update_display_tool(&tool_state, scene, input_state, &color_renderer);
    
    imgui.begin("tools");
    buttonName := "Building Tool ";
    if(imgui.button("Building Tool"))
    {
    	tool_state = Building_Placement_Tool_State{};
    }
    imgui.end();

    if input_state.mouse_states[2] == .Pressed
    {
    	container.table_add(&arcs, Wave_Arc{100, worldMousePos, {0, 0, 2 * math.PI}, container.invalid_handle(&buildings)});
	}
	arc_it := container.table_iterator(&arcs);
	for arc in container.table_iterate(&arc_it) do arc.radius += deltaTime * 100;
    
    planet_it := container.table_iterator(&planets);
    for planet in container.table_iterate(&planet_it)
    {
    	update_wave_collision(&arcs, 100, 500, planet);
    }

    l_it := container.table_iterator(&loading_buildings);
    for h in container.iterate(&l_it)
	{
		b := container.table_get(&buildings, h.building);
		bb := to_regular_hitbox(b);
		arc_it = container.table_iterator(&arcs);
		for arc in container.table_iterate(&arc_it)
		{
			if h.building.id != arc.ignored_building.id && collision_bb_arc(&bb, arc, 10) do h.energy += deltaTime;
			log.info(h);
		}
	}

	update_wave_emitters(&wave_emitters, &buildings, &arcs);

    render_wave(&arcs, 10, 5, {1, 1, 0, 1}, &color_renderer);

    it := container.table_iterator(&buildings);
    for b in container.iterate(&it)
	{
		render_building(b, &color_renderer);
	}

	planet_it = container.table_iterator(&planets);
	for p in container.table_iterate(&planet_it)
	{
		render_planet(&color_renderer, p, 200);
	}

	test_arc : Wave_Arc;
	test_arc.radius = 200;
	test_arc.center = worldMousePos;
	test_arc.angular_size = math.PI / 2;
	test_result := false;

	it = container.table_iterator(&buildings);
	for b in container.iterate(&it)
	{
		hitbox := to_regular_hitbox(b.hitbox);
		testCircle : Circle = {worldMousePos, 200};
		if(collision_bb_arc(&hitbox, &test_arc, 10))
		{
			test_result = true;
		}
	}

	render.render_sprite(&scene.sprite_renderer.buffer, spaceship_sprite, {0, 0}, render.Color{1, 1, 1, 1}, 100);

	//render_wave({test_arc}, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	render.render_buffer_content(&color_renderer, &camera);
	gl.BindTexture(gl.TEXTURE_2D, container.table_get(&textures, spaceship_sprite.texture).texture_id);
	render.render_buffer_content(&scene.sprite_renderer, &camera);
    render.clear_render_buffer(&color_renderer.buffer);
    render.clear_render_buffer(&scene.sprite_renderer.buffer);
}