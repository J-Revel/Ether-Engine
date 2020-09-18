package tool;

import "src:render";
import "src:gameplay/entity";

vec2 :: [2]f32;

display_building_placement :: proc(world_pos: vec2, using scene_instance: scene.Instance, render_buffer: ^render.RenderBuffer)
{
	building : entity.Building;
	for planetInstance in &planets
    {
        if(linalg.vector_length(worldMousePos - planetInstance.pos) < linalg.vector_length(worldMousePos - building.planet.pos))
        {
            building.planet = &planetInstance;
        }
    }
    building.angle = planet.closestSurfaceAngle(building.planet, worldMousePos, 100);
	entity.renderBuilding(&building, &renderBuffer);
}