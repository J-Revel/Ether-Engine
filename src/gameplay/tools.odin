package gameplay;

import "src:render";
import "src:input"
import "core:log"
import "core:math/linalg"
import "src:../imgui"
import "core:strconv"


Basic_Tool_State :: struct
{
	last_mouse_pos: [2]f32,
}

Building_Placement_Tool_State :: struct
{
	selected_building: int
}

Tool_State:: union
{
	Basic_Tool_State,
	Building_Placement_Tool_State,
}

update_display_tool :: proc(tool_state: ^Tool_State, scene: ^Scene, input_state: ^input.State, render_system: ^render.Render_System)
{
	#partial switch state in tool_state
	{
		case Basic_Tool_State:
		{
			update_basic_tool(input_state, &scene.camera, tool_state);
		}
		case Building_Placement_Tool_State:
		{
			update_building_placement_tool(input_state, scene, tool_state, render_system);
		}
	}
}

update_basic_tool :: proc(input_state: ^input.State, camera: ^render.Camera, tool_state: ^Tool_State)
{
	f_mouse_pos := [2]f32{cast(f32)input_state.mouse_pos.x, cast(f32)input_state.mouse_pos.y};
	
	tool : ^Basic_Tool_State = &tool_state.(Basic_Tool_State);
	if input_state.mouse_states[0] == .Pressed
	{
		tool.last_mouse_pos = f_mouse_pos;
	}
	if input.is_down(input_state.mouse_states[0])
	{
		offset := f_mouse_pos - tool.last_mouse_pos;
	    camera.pos.x -= cast(f32)offset.x;
	    camera.pos.y += cast(f32)offset.y;
	}
	tool.last_mouse_pos = f_mouse_pos;
}

update_building_placement_tool :: proc(input_state: ^input.State, scene: ^Scene, tool_state: ^Tool_State, render_system: ^render.Render_System)
{
	tool : ^Building_Placement_Tool_State = &tool_state.(Building_Placement_Tool_State);
	if(!input_state.mouse_captured)
	{
		building : Building;
		building.size = building_render_types[tool.selected_building].render_size;
		building.render_data = &building_render_types[tool.selected_building];
		world_pos := render.camera_to_world(&scene.camera, render_system, input_state.mouse_pos);
		for planetInstance in &scene.planets
	    {
	        if(building.planet == nil || linalg.vector_length(world_pos - planetInstance.pos) < linalg.vector_length(world_pos - building.planet.pos))
	        {
	            building.planet = &planetInstance;
	        }
	    }
	    building.angle = closestSurfaceAngle(building.planet, world_pos, 100);
		render_building(&building, render_system);

		if(input_state.mouse_states[2] == .Pressed)
		{
			tool_state^ = Basic_Tool_State{};
		}

		if(input_state.mouse_states[0] == .Pressed)
		{
			append(&scene.buildings, building);
		}
	}
	imgui.begin("Buildings");
	for i := 0; i<len(building_render_types); i += 1
    {

    	buf :[500]byte;
	    buttonName := strconv.itoa(buf[0:500], i);
	    
    	if(imgui.button(buttonName))
	    {
	    	log.info(i);
	    	tool.selected_building = i;
	    }
	}
    imgui.end();
}