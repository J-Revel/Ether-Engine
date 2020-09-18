package tool;

import "src:render";
import "src:gameplay/entity";
import "src:gameplay/planet"
import "core:math/linalg"

vec2 :: [2]f32;

display_building_placement :: proc(world_pos: vec2, buildings: []entity.Building, planets: ^[]planet.Instance, render_system: ^render.Render_System)
{
	building : entity.Building;
	for planetInstance in planets
    {
        if(linalg.vector_length(world_pos - planetInstance.pos) < linalg.vector_length(world_pos - building.planet.pos))
        {
            building.planet = &planetInstance;
        }
    }
    building.angle = planet.closestSurfaceAngle(building.planet, world_pos, 100);
	entity.renderBuilding(&building, render_system);
}