package gameplay

import "../container"
import "../render"
import "core:log"

Transform :: struct
{
	parent: container.Handle(Transform),
	pos: [2]f32, // position relative to parent
	scale: f32,
	angle: f32
}

Transform_Handle :: container.Handle(Transform);
Transform_Table :: container.Table(Transform);

get_transform_absolute :: proc(transform_id: Transform_Handle) -> (pos: [2]f32, angle: f32, scale: f32)
{
	scale = 1;
	for cursor := transform_id; cursor.id > 0;
	{
		cursor_data := container.handle_get(cursor);
		log.info(cursor_data.parent);
		if cursor_data != nil
		{
			pos += cursor_data.pos;
			cursor = cursor_data.parent;
			scale *= cursor_data.scale;
		}
		else
		{
			cursor = {};
		}
	}
	return;
}

Sprite_Component :: struct
{
	transform: Transform_Handle,
	sprite: render.Sprite_Handle,
}

render_sprite_components :: proc(render_buffer: ^render.Sprite_Render_Buffer, table: ^container.Table(Sprite_Component))
{
	it := container.table_iterator(table);
    for sprite_component in container.table_iterate(&it)
    {
    	pos, angle, scale := get_transform_absolute(sprite_component.transform);
    	sprite := container.handle_get(sprite_component.sprite);
    	render.render_sprite(render_buffer, sprite, pos, {1, 1, 1, 1}, scale);
    }
}