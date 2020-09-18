package scene
import "src:gameplay/entity"
import "src:gameplay/planet"
import "src:render"
import "core:log"
import "src:gameplay/tool"


Instance :: struct
{
	buildings: [dynamic]entity.Building,
	planets: [dynamic]planet.Instance,
	camera: render.Camera,
	tool_type: tool.Tool_Type,
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

update_and_render :: proc(using scene: ^Instance, deltaTime: f32, renderBuffer: ^render.RenderBuffer)
{

    tool.update_display_tool(&tool_type, &tool_state, &camera, input_state);
	for b in &buildings
	{
		entity.renderBuilding(&b, renderBuffer);
	}
	for p in &planets
	{
		planet.render(renderBuffer, &p, 200);
	}
}


