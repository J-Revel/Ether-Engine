package tool;

import "src:render";
import "src:gameplay/entity";
import "src:input"

Tool_Type :: enum
{
	None,
	Building_Placement,

};

Basic_Tool_State :: struct
{
	last_mouse_pos: [2]f32,
}

Tool_State:: union
{
	Basic_Tool_State,
}

update_display_tool :: proc(tool_type: Tool_Type, tool_state: ^Tool_State, camera: ^render.Camera, input_state: ^input.State)
{
	#partial switch tool_type
	{
		case Tool_Type.None:
		{
			update_basic_tool(input_state, camera, &tool_state.Basic_Tool_State);
		}
	}
}

update_basic_tool :: proc(input_state: ^input.State, camera: ^render.Camera, tool_state: ^Basic_Tool_State)
{
	if input_state.mouse_states[0] == .Pressed
	{
		tool_state.last_mouse_pos = input_state.mouse_pos;
	}
	if input.is_down(&input_state.mouse_states[0])
	{
		offset := input_state.mouse_pos - tool_state.last_mouse_pos;
	    camera.pos.x -= cast(f32)offset.x;
	    camera.pos.y += cast(f32)offset.y;
	}
}