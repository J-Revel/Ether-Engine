package scene
import "src:gameplay/entity"
import "src:gameplay/planet"
import "src:render"
import "core:log"
import "src:gameplay/tool"
import "src:input"


Instance :: struct
{
	buildings: [dynamic]entity.Building,
	planets: [dynamic]planet.Instance,
	camera: render.Camera,
	tool_state: tool.Tool_State,
}

init :: proc(using scene: ^Instance)
{
	camera.zoom = 1;
	for i := 0; i < 10; i+=1
	{
		p : planet.Instance;
		planet.generate(&p, 100, 10);
		p.pos = [2]f32{500 * cast(f32)i, 0};
		append(&planets, p);
	}
}

update_and_render :: proc(using scene: ^Instance, deltaTime: f32, render_system: ^render.Render_System, input_state: ^input.State)
{
	worldMousePos := [2]f32{
        cast(f32)input_state.mouse_pos.x + camera.pos.x - render_system.screen_size.x / 2,
        -cast(f32)input_state.mouse_pos.y + camera.pos.y + render_system.screen_size.y / 2
    };
    tool.update_display_tool(&tool_state, &camera, input_state);
	for b in &buildings
	{
		entity.renderBuilding(&b, render_system);
	}
	for p in &planets
	{
		planet.render(render_system, &p, 200);
	}
    render.renderBufferContent(render_system, &camera);
}


