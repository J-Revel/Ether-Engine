package tool;

import "src:render";
import "src:gameplay/entity";
import "src:input"


Basic_Tool_State :: struct
{
	last_mouse_pos: [2]f32,
}

Tool_State:: union
{
	Basic_Tool_State,
}

update_display_tool :: proc(tool_state: ^Tool_State, camera: ^render.Camera, input_state: ^input.State)
{
	#partial switch state in tool_state
	{
		case Basic_Tool_State:
		{
			update_basic_tool(input_state, camera, &tool_state.(Basic_Tool_State));
		}
	}
}

update_basic_tool :: proc(input_state: ^input.State, camera: ^render.Camera, tool_state: ^Basic_Tool_State)
{
	f_mouse_pos := [2]f32{cast(f32)input_state.mouse_pos.x, cast(f32)input_state.mouse_pos.y};
	if input_state.mouse_states[0] == .Pressed
	{
		tool_state.last_mouse_pos = f_mouse_pos;
	}
	if input.is_down(input_state.mouse_states[0])
	{
		offset := f_mouse_pos - tool_state.last_mouse_pos;
	    camera.pos.x -= cast(f32)offset.x;
	    camera.pos.y += cast(f32)offset.y;
	}
}