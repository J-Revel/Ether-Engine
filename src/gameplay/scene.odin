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
	buildings: container.Table(Building, Building_ID),
	loading_buildings: [dynamic]Loading_Building,
	planets: [dynamic]Planet,
	camera: render.Camera,
	tool_state: Tool_State,
    arcs: [dynamic]Wave_Arc,
}

init_scene :: proc(using scene: ^Scene)
{
	camera.zoom = 1;
	for i := 0; i < 10; i+=1
	{
		p : Planet;
		generate(&p, rand.float32() * 200 + 100, 10);
		p.pos = [2]f32{800 * cast(f32)i, 0};
		append(&planets, p);
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
    	append(&arcs, Wave_Arc{100, worldMousePos, {0, 0, 2 * math.PI} });
	}
	for arc in &arcs do arc.radius += deltaTime * 100;
    for planet in &planets do update_wave_collision(&arcs, 100, 500, &planet);

    for h in &loading_buildings
	{
		bb := to_regular_hitbox(h.building);
		for arc in &arcs
		{
			if collision_bb_arc(&bb, &arc, 10)
				do h.energy += deltaTime;
		}
	}

    render_wave(arcs[:], 10, 5, {1, 1, 0, 1}, render_system);

    for index in container.table_elements(&buildings)
	{
		render_building(container.table_get(&buildings, index), render_system);
	}

	for p in &planets
	{
		render_planet(render_system, &p, 200);
	}

	test_arc : Wave_Arc;
	test_arc.radius = 200;
	test_arc.center = worldMousePos;
	test_arc.angular_size = math.PI / 2;
	test_result := false;
	for index in container.table_elements(&buildings)
	{
		b := container.table_get(&buildings, index);
		hitbox := to_regular_hitbox(b.hitbox);
		testCircle : Circle = {worldMousePos, 200};
		if(collision_bb_arc(&hitbox, &test_arc, 10))
		{
			test_result = true;
		}

	}

	render_wave({test_arc}, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	render.renderBufferContent(render_system, &camera);
}