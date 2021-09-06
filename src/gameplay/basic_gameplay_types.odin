package gameplay

import "../container"
import "../render"
import "core:log"
import "../objects"

import "../../libs/imgui"
import "core:fmt"

Sprite_Component :: struct
{
	transform: objects.Transform_Hierarchy_Handle,
	sprite: render.Sprite_Handle,
}

render_sprite_components :: proc(hierarchy: ^objects.Transform_Hierarchy, render_buffer: ^render.Sprite_Render_System, table: ^container.Table(Sprite_Component))
{
	it := container.table_iterator(table);
    for sprite_component, sprite_handle in container.table_iterate(&it)
    {
        imgui.text_unformatted(fmt.tprint(sprite_component.transform, sprite_component.sprite));
        if container.is_valid(sprite_component.transform) && container.is_valid(sprite_component.sprite)
        {
            absolute_transform := objects.get_absolute_transform(hierarchy, sprite_component.transform);
	    	sprite := container.handle_get(sprite_component.sprite);
	    	render.render_sprite(render_buffer, sprite, transmute(render.Transform)absolute_transform, render.rgb(255, 255, 255));
    	}
    }
}
