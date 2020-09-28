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


Scene :: struct
{
	camera: render.Camera,
	tool_state: Tool_State,
	buildings: container.Table(Building),
	loading_buildings: container.Table(Loading_Building),
	wave_emitters: container.Table(Wave_Emitter),
	planets: container.Table(Planet),
    arcs: container.Table(Wave_Arc),
    db: container.Database
}

init_scene :: proc(using scene: ^Scene)
{
	container.table_init(&buildings, 1000);
	container.table_init(&loading_buildings, 1000);
	container.table_init(&planets, 1000);
	container.table_init(&arcs, 1000);
	container.table_init(&wave_emitters, 100);
	container.table_database_add(&db, "buildings", &buildings);
	container.table_database_add(&db, "loading_buildings", &loading_buildings);
	container.table_database_add(&db, "planets", &planets);
	container.table_database_add(&db, "arcs", &arcs);
	container.table_database_add(&db, "wave_emitters", &wave_emitters);
	camera.zoom = 1;
	for i := 0; i < 10; i+=1
	{
		p : Planet;
		generate(&p, rand.float32() * 200 + 100, 10);
		p.pos = [2]f32{800 * cast(f32)i, 0};
		container.table_add(&planets, p);
	}
	tool_state = Basic_Tool_State{};

}

time : f32 = 0;

update_and_render :: proc(using scene: ^Scene, deltaTime: f32, render_system: ^render.Render_System, input_state: ^input.State)
{
	worldMousePos := render.camera_to_world(&scene.camera, render_system, input_state.mouse_pos);
    update_display_tool(&tool_state, scene, input_state, render_system);
	
    
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
			if h.building.id != arc.ignored_building.id && collision_bb_arc(&bb, arc, 10)
				do h.energy += deltaTime;
			log.info(h);
		}
	}

	update_wave_emitters(&wave_emitters, &buildings, &arcs);

    render_wave(&arcs, 10, 5, {1, 1, 0, 1}, render_system);

    it := container.table_iterator(&buildings);
    for b in container.iterate(&it)
	{
		render_building(b, render_system);
	}

	planet_it = container.table_iterator(&planets);
	for p in container.table_iterate(&planet_it)
	{
		render_planet(render_system, p, 200);
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

	//render_wave({test_arc}, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	render.renderBufferContent(render_system, &camera);
}