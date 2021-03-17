package gameplay

import "../container"
import "../render"
import "core:log"
import "../objects"

Sprite_Component :: struct
{
	transform: objects.Transform_Handle,
	sprite: render.Sprite_Handle,
}

render_sprite_components :: proc(render_buffer: ^render.Sprite_Render_System, table: ^container.Table(Sprite_Component))
{
	it := container.table_iterator(table);
    for sprite_component, sprite_handle in container.table_iterate(&it)
    {
    	pos, angle, scale := objects.get_transform_absolute(sprite_component.transform);
    	if container.is_valid(sprite_component.sprite)
    	{
	    	sprite := container.handle_get(sprite_component.sprite);
	    	render.render_sprite(render_buffer, sprite, pos, {1, 1, 1, 1}, scale);
    	}
    }
}