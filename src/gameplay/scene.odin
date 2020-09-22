package gameplay

import "src:render"
import "core:log"
import "src:input"
import "core:strconv"

import imgui "src:../imgui"
import "core:math/rand"
import "core:math"

import sdl "shared:odin-sdl2"


Scene :: struct
{
	buildings: [dynamic]Building,
	loading_buildings: [dynamic]Loading_Building,
	planets: [dynamic]Planet,
	camera: render.Camera,
	tool_state: Tool_State,
    wave: Wave
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
    	append(&wave.arcs, Wave_Arc{100, worldMousePos, 0, 0, 2 * math.PI });
	}
	for arc in &wave.arcs do arc.radius += deltaTime * 100;
    for planet in &planets do update_wave_collision(&wave, 100, 500, &planet);

    for h in &loading_buildings
	{
		h.energy += update_wave_collision(&wave, 30, 500, h.building);
		log.info(h.energy);
	}

    render_wave(&wave, 10, 5, {1, 1, 0, 1}, render_system);

    for b in &buildings
	{
		render_building(&b, render_system);
	}

	for p in &planets
	{
		render_planet(render_system, &p, 200);
	}

	test_arc : Wave_Arc;
	test_arc.radius = 200;
	test_arc.center = worldMousePos;
	test_arc.angular_size = math.PI * 2;
	test_wave : Wave = {};
	append(&test_wave.arcs, test_arc);
	test_result := false;
	for b in &buildings
	{
		hitbox := to_regular_hitbox(b.hitbox);
		testCircle : Circle = {worldMousePos, 200};
		if(collision_hitbox_empty_circle(&hitbox, &testCircle))
		{
			test_result = true;
		}

	}

	render_wave(&test_wave, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	render.renderBufferContent(render_system, &camera);
}