package gameplay

import "../render"
import "core:log"
import "../input"
import "core:strconv"

import imgui "../../libs/imgui"
import freetype "../../libs/freetype"
import "core:math/rand"
import "core:math"
import "core:math/linalg"
import "core:fmt"

import sdl "shared:odin-sdl2"

import container "../container"

import os "core:os"

import json "core:encoding/json"

import gl "shared:odin-gl";

import "../animation"

import "../objects"

import "core:reflect"

import "../ui"
import "../util"


Rect :: struct
{
	pos: [2]f32,
	size: [2]f32,
}

Scene :: struct
{
	camera: render.Camera,
	prefab_tables: objects.Named_Table_List,
    //color_renderer: render.Color_Render_System,
    sprite_renderer: render.Sprite_Render_System,

	ui_ssbo_renderer: ui.Render_System,
	ui_draw_list: ui.Draw_Command_List,

    ui_renderer: render.Sprite_Render_System,
	ui_test_renderer: ui.UI_Render_System,
    transforms: objects.Transform_Table,
    transform_hierarchy: objects.Transform_Hierarchy,
    sprite_components: container.Table(Sprite_Component),
    using sprite_database: ^render.Sprite_Database,
    using animation_database: animation.Animation_Database,

    scene_database: container.Database,
	font: render.Font,
	test_sprite: render.Sprite_Handle,
	rune_sprites: map[rune]render.Sprite_Handle,
	editor_font: render.Font,
}

init_empty_scene :: proc(using scene: ^Scene, sprite_db: ^render.Sprite_Database)
{
	sprite_database = sprite_db;
	objects.table_database_add_init(&prefab_tables, "sprite_component", &sprite_components, 5000);
	objects.transform_hierarchy_init(&transform_hierarchy, 5000);

	animation.init_animation_database(&prefab_tables, &animation_database);

	container.database_add(&scene_database, sprite_database);
	container.database_add(&scene_database, &animation_database);
	container.database_add(&scene_database, &transform_hierarchy);

	render.init_sprite_renderer(&sprite_renderer.render_state, .World);
	render.init_sprite_renderer(&ui_renderer.render_state, .UI);
	ui.init_renderer(&ui_ssbo_renderer);
	//render.init_color_renderer(&color_renderer.render_state);

	camera.zoom = 1;
}

test_animation_keyframes : [4]animation.Keyframe(f32) =
{
	animation.Keyframe(f32){0, 0},
	animation.Keyframe(f32){0.5, 1},
	animation.Keyframe(f32){0.75, 0.5},
	animation.Keyframe(f32){1, 1},
};

test_texture_id: u32;

init_main_scene :: proc(using scene: ^Scene, sprite_db: ^render.Sprite_Database)
{
	using container;
	init_empty_scene(scene, sprite_db);

	font_load_ok: bool;
	editor_font, font_load_ok = render.load_font("resources/fonts/Roboto-Regular.ttf", 12);
	assert(font_load_ok);

	ui.init_ctx(&ui_ctx, sprite_database, &editor_font);
	test_sprite, _ = container.table_add(&sprite_database.sprites, render.Sprite{
		ui_ctx.font_atlas.texture_handle,
		"test",
		render.Sprite_Data {
			anchor = [2]f32{0, 0},
			clip = util.Rect{ pos=[2]f32{0, 0}, size = [2]f32{1, 1}},
		},
	});

	texture_id: u32;
    gl.GenTextures(1, &texture_id);

    data: []u8 = { 255, 0, 0, 255 };

    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0]);
    gl.BindTexture(gl.TEXTURE_2D, 0);
	bindless_id := render.GetTextureHandleARB(texture_id);
	render.MakeTextureHandleResidentARB(bindless_id);

	test_texture_id = texture_id;

	font_texture := container.handle_get(ui_ctx.font_atlas.texture_handle);
	log.info(font_texture.bindless_id);
}

time : f32 = 0;
ui_ctx: ui.UI_Context;
window_state := ui.Window_State {
	rect = ui.UI_Rect{
		size = {1200, 800},
	},
};

test_value := 503;

update_and_render :: proc(using scene: ^Scene, delta_time: f32, input_state: ^input.State, viewport: render.Viewport)
{
	time += delta_time;
	animation.update_animations(&animation_players, delta_time);

	// spaceship_sprite, sprite_found := render.get_sprite_any_texture(&sprite_database, "spaceship");
	

	// spaceship_sprite_data := container.handle_get(spaceship_sprite);
	//render.render_sprite(&scene.sprite_renderer.buffer, spaceship_sprite_data, {0, 0}, render.Color{1, 1, 1, 1}, 100);
	render_sprite_components(&transform_hierarchy, &sprite_renderer, &sprite_components);

	ui.reset_ctx(&ui_ctx, viewport.size);
	ui.update_input_state(&ui_ctx, input_state);
	
	//ui.rect(&draw_list, {0, 0}, {200, 200}, {1, 1, 1, 1});

	
	//ui.layout_draw_rect(&ui_ctx, {}, {}, render.rgb(128, 255, 128), 20);
	if ui.window(&ui_ctx, &window_state, 40)
	{
		//log.info(container.handle_get(rune_sprites['a']));
		//ui.element_draw_textured_rect(ui.default_anchor, {}, {1, 1, 1, 1}, rune_sprites['a'], &ui_ctx);
		//allocated_space = ui.allocate_element_space(&ui_ctx, [2]f32{50, 50});
		//ui.ui_element(allocated_space, &ui_ctx);
		//ui.element_draw_textured_rect(ui.default_anchor, {}, {1, 1, 1, 1}, rune_sprites['e'], &ui_ctx);
		ui.label(&ui_ctx, fmt.tprint(ui_ctx.input_state.cursor_state), .Center);
		ui.label(&ui_ctx, fmt.tprint(util.get_fps()));
		ui.label(&ui_ctx, fmt.tprint(len(ui_ctx.content_size_fitters)));
		drag_cache: ui.Drag_State;
		ui.drag_int(&ui_ctx, &test_value, ui.id_from_location());
		ui.slider(&ui_ctx, &test_value, 0, 1000, 20, int(ui_ctx.editor_config.line_height));

		split_weights := [3]f32 {1, 1, 1};
		columns : []ui.UI_Rect = ui.vsplit(&ui_ctx, split_weights[:], 20, context.allocator);
		defer delete(columns);
		
		ui.push_layout(&ui_ctx, ui.Layout{rect = columns[0], direction = [2]int{0, 1}});
		ui.add_content_size_fitter(&ui_ctx);
		ui.label(&ui_ctx, "default", .Center);
		ui.rect_theme_editor(&ui_ctx, &ui_ctx.current_theme.button.default_theme);
		ui.pop_layout(&ui_ctx);
		ui.push_layout(&ui_ctx, ui.Layout{rect = columns[1], direction = [2]int{0, 1}});
		ui.add_content_size_fitter(&ui_ctx);
		ui.label(&ui_ctx, "hovered", .Center);
		ui.rect_theme_editor(&ui_ctx, &ui_ctx.current_theme.button.hovered_theme);
		ui.pop_layout(&ui_ctx);
		ui.push_layout(&ui_ctx, ui.Layout{rect = columns[2], direction = [2]int{0, 1}});
		ui.add_content_size_fitter(&ui_ctx);
		ui.label(&ui_ctx, "clicked", .Center);
		ui.rect_theme_editor(&ui_ctx, &ui_ctx.current_theme.button.clicked_theme);
		ui.pop_layout(&ui_ctx);
		for i in 0..3
		{
			if ui.button("test", {100, 100}, &ui_ctx, ui.id_from_index(i))
			{
				log.info("BUTTON3");
			}
		}
		if ui.button("test", {150, 100}, &ui_ctx)
		{
			log.info("BUTTON2");
		}
		if ui.button("test", {100, 100}, &ui_ctx)
		{
			log.info("BUTTON3");
		}
		if ui.button("test", {100, 20}, &ui_ctx)
		{
			log.info("BUTTON3");
		}
		if ui.button("test", {100, 60}, &ui_ctx)
		{
			log.info("Save Theme");
			log.info(ui.save_theme("config/ui/base_theme.json", ui_ctx.current_theme));
		}
		ui.window_end(&ui_ctx, &window_state);
	}
	//ui.pop_layout(&ui_ctx);
}

do_render :: proc(using scene: ^Scene, viewport: render.Viewport)
{
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
	gl.Viewport(i32(viewport.top_left.x), i32(viewport.top_left.y), i32(viewport.size.x), i32(viewport.size.y));

	ui.render_draw_list(&ui_ctx.draw_list, &scene.ui_renderer);

	//render_wave({test_arc}, 10, 5, {1, test_result ? 1 : 0, 0, 1}, render_system);
	
	// render.render_buffer_content(&color_renderer, &camera);
	// texture_id := container.table_get(&textures, spaceship_sprite_data.texture).texture_id;
	
	render.render_sprite_buffer_content(&scene.sprite_renderer, &camera, viewport);
	render.render_ui_buffer_content(&scene.ui_renderer, viewport);
	font_texture := container.handle_get(ui_ctx.font_atlas.texture_handle);
	if scene.ui_draw_list.rect_command_count> 0
	{
		ui.render_ui_draw_list(&scene.ui_ssbo_renderer, &scene.ui_draw_list, viewport, font_texture);
	}
	if ui_ctx.ui_draw_list.rect_command_count > 0
	{
		ui.render_ui_draw_list(&ui_ctx.renderer, &ui_ctx.ui_draw_list, viewport, font_texture);
	}

	ui_camera := render.Camera{
		world_pos = linalg.to_f32(viewport.size / 2),
		zoom = 1,
	};
    //render.render_buffer_content(&scene.color_renderer, &ui_camera, viewport);
    //render.clear_render_buffer(&color_renderer.buffer);
    render.clear_sprite_render_buffer(&scene.sprite_renderer);
    render.clear_sprite_render_buffer(&scene.ui_renderer);
}
