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

import "../editor"

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
    sprites: container.Table(render.Sprite),
    transforms: Transform_Table,
    sprite_components: container.Table(Sprite_Component),
    show_editor: bool,

	editor_state: editor.Editor_State
}

init_scene :: proc(using scene: ^Scene)
{
	container.table_database_add_init(&db, "building", &buildings, 1000);
	container.table_database_add_init(&db, "loading_building", &loading_buildings, 1000);
	container.table_database_add_init(&db, "planet", &planets, 1000);
	container.table_database_add_init(&db, "arc", &arcs, 1000);
	container.table_database_add_init(&db, "wave_emitter", &wave_emitters, 100);
	container.table_database_add_init(&db, "texture", &textures, 100);
	container.table_database_add_init(&db, "sprite", &sprites, 200);
	container.table_database_add_init(&db, "transform", &transforms, 10000);
	container.table_database_add_init(&db, "sprite_component", &sprite_components, 500);

	render.init_sprite_renderer(&sprite_renderer.render_state);
	render.init_color_renderer(&color_renderer.render_state);

	camera.zoom = 1;
	
	render.load_sprites_from_file("test.sprites", &textures, &sprites);

	log.info(sprites);
	spaceship_sprite, sprite_found := render.get_sprite("spaceship", &sprites);
	log.info(spaceship_sprite, sprite_found);
	prefab_instance, ok := container.load_prefab("config/prefabs/buildings/ship.prefab", scene.db);
	test_input: map[string]any;
	test_input["sprite"] = spaceship_sprite;
	test_input["pos"] = [2]f32{0, 0};
	test_input["scale"] = f32(0.1);

	container.prefab_instantiate(&db, &prefab_instance, test_input);

	test_input["sprite"] = spaceship_sprite;
	test_input["pos"] = [2]f32{-350, 0};
	test_input["scale"] = f32(0.5);

	container.prefab_instantiate(&db, &prefab_instance, test_input);

	editor.init_editor(&editor_state, container.handle_get(spaceship_sprite).texture);
	tool_state = Basic_Tool_State{};

}

time : f32 = 0;

update_and_render :: proc(using scene: ^Scene, deltaTime: f32, screen_size: [2]f32, input_state: ^input.State)
{

	color_renderer.screen_size = screen_size;
	sprite_renderer.screen_size = screen_size;
	worldMousePos := render.camera_to_world(&scene.camera, &color_renderer, input_state.mouse_pos);
    update_display_tool(&tool_state, scene, input_state, &color_renderer);
    
    imgui.begin("tools");

    switch(input.get_mouse_state(input_state, 0))
    {
    	case .Pressed:
    		imgui.text("Pressed");
    	case .Down:
    		imgui.text("Down");
    	case .Released:
    		imgui.text("Released");
    	case .Up:
    		imgui.text("Up");
    }
    buttonName := "Building Tool ";
    if(imgui.button("Building Tool"))
    {
    	tool_state = Building_Placement_Tool_State{};
    }
    imgui.end();

    if input.get_mouse_state(input_state, 2) == .Pressed
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

	if input.get_key_state(input_state, sdl.Scancode.Tab) == .Pressed do show_editor = !show_editor;

	spaceship_sprite, sprite_found := render.get_sprite("spaceship", &sprites);
	if show_editor
	{
		sprite_data := container.handle_get(spaceship_sprite);
		texture_data := container.handle_get(sprite_data.texture);
		editor.update_editor(&editor_state, screen_size);
	}

	spaceship_sprite_data := container.handle_get(spaceship_sprite);
	//render.render_sprite(&scene.sprite_renderer.buffer, spaceship_sprite_data, {0, 0}, render.Color{1, 1, 1, 1}, 100);
	render_sprite_components(&scene.sprite_renderer.buffer, &sprite_components);

	//render_wave({test_arc}, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	render.render_buffer_content(&color_renderer, &camera);
	texture_id := container.table_get(&textures, spaceship_sprite_data.texture).texture_id;
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);
	render.render_buffer_content(&scene.sprite_renderer, &camera);
    render.clear_render_buffer(&color_renderer.buffer);
    render.clear_render_buffer(&scene.sprite_renderer.buffer);
}