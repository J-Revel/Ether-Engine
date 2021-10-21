package ui

import "core:log"
import "core:hash"
import "core:math/linalg"
import "core:math"
import "core:runtime"
import "core:mem"
import "core:strings"
import "core:fmt"

import "../input"
import "../container"
import "../render"
import "../util"

default_id :: proc(ui_id: UI_ID, location := #caller_location) -> UI_ID
{
	if ui_id == 0 do return id_from_location(location);
	return ui_id;
}

join_rects :: proc(A: UI_Rect, B: UI_Rect) -> (result: UI_Rect)
{
	if A.size.x == 0
	{
		result.size.x = B.size.x;
		result.pos.x = B.pos.x;
	}
	else if B.size.x == 0
	{
		result.size.x = A.size.x;
		result.pos.x = B.pos.x;
	}
	else
	{
		result.pos.x = min(A.pos.x, B.pos.x);
		max_x := max(A.pos.x + A.size.x, B.pos.x + B.size.x);
		result.size.x = max_x - result.pos.x;
	}
	if A.size.y == 0
	{
		result.size.y = B.size.y;
		result.pos.y = B.pos.y;
	}
	else if B.size.y == 0
	{
		result.size.y = A.size.y;
		result.pos.y = B.pos.y;
	}
	else
	{
		result.pos.y = min(A.pos.y, B.pos.y);
		max_y := max(A.pos.y + A.size.y, B.pos.y + B.size.y);
		result.size.y = max_y - result.pos.y;
	}
	return result;
}

simple_padding :: #force_inline proc(value: int) -> Padding
{
	return Padding{[2]int{value, value}, [2]int{value, value}};
}

init_ctx :: proc(ui_ctx: ^UI_Context, sprite_database: ^render.Sprite_Database)
{
	ui_ctx.sprite_table = &sprite_database.sprites;
	render.init_font_atlas(&sprite_database.textures, &ui_ctx.font_loader.font_atlas); 
	init_renderer(&ui_ctx.renderer);
	
	error: Theme_Load_Error;
	ui_ctx.current_theme, error = load_theme("config/ui/base_theme.json");
	fonts := [?]render.Font_Asset{
		ui_ctx.current_theme.text.default.font_asset, 
		ui_ctx.current_theme.text.title.font_asset,
	};
	log.info("Fonts to load :", fonts);
	load_fonts(&ui_ctx.font_loader, fonts[:]);
	base_font := ui_ctx.loaded_fonts[ui_ctx.current_theme.text.default.font_asset];
	ui_ctx.editor_config.line_height = int(base_font.line_height) + 4;
	if error != nil do log.info("Error loading theme :", error);
	log.info(ui_ctx.current_theme);

	ui_ctx.current_theme.number_editor.text = &ui_ctx.current_theme.text.default;
	ui_ctx.current_theme.number_editor.buttons = &ui_ctx.current_theme.button;
	ui_ctx.current_theme.number_editor.height = 50;
	ui_ctx.current_theme.number_editor.button_width = 50;

}

load_fonts :: proc(loader: ^Font_Loader, assets: []render.Font_Asset)
{
	for loaded_font_asset, loaded_font in &loader.loaded_fonts
	{
		render.free_font(loaded_font);
	}
	clear(&loader.loaded_fonts);
	for font_asset in assets
	{
		loaded_font, font_load_ok := render.load_font(font_asset.path, font_asset.font_size, context.allocator);
		if font_load_ok do loader.loaded_fonts[font_asset] = loaded_font;
		else do log.info("Error loading font", font_asset);
	}
	
}

update_input_state :: proc(ui_ctx: ^UI_Context, input_state: ^input.State)
{
	using ui_ctx.input_state;
	last_cursor_pos = cursor_pos;
	cursor_pos = input_state.mouse_pos;
	cursor_offset := cursor_pos - last_cursor_pos; 
	switch cursor_state 
	{
		case .Normal:
			if input.Key_State_Flags.Down in input.get_mouse_state(input_state, 0)
			{
				if ui_ctx.elements_under_cursor[.Press] == 0 && ui_ctx.elements_under_cursor[.Drag] != 0
				{
					cursor_state = Cursor_Input_State.Drag;
					drag_amount = {};
					delta_drag = {};
					drag_target = ui_ctx.elements_under_cursor[Interaction_Type.Drag];
				}
				else
				{
					cursor_state = Cursor_Input_State.Press;
				}
			}
		case .Press:
			cursor_state = Cursor_Input_State.Down;
			drag_amount = {};
			delta_drag = {};
		case .Down:
			drag_amount += cursor_offset;
			delta_drag = cursor_offset;
			max_down_distance: int= 10;
			if ui_ctx.elements_under_cursor[Interaction_Type.Drag] != 0
			{
				drag_target = ui_ctx.elements_under_cursor[Interaction_Type.Drag];
			}
			if linalg.vector_length2(drag_amount) > max_down_distance * max_down_distance
			{
				cursor_state = Cursor_Input_State.Drag;
				delta_drag = {};
			}
			else if input.Key_State_Flags.Down not_in input.get_mouse_state(input_state, 0)
			{
				cursor_state = Cursor_Input_State.Click_Release;
			}
		case .Drag:
			drag_amount += cursor_offset;
			delta_drag = cursor_offset;
			if input.Key_State_Flags.Down not_in input.get_mouse_state(input_state, 0)
			{
				cursor_state = Cursor_Input_State.Drag_Release;
			}
		case .Click_Release:
			cursor_state = Cursor_Input_State.Normal;
			drag_amount = {};
			delta_drag= {};
			drag_target = 0;
		case .Drag_Release:
			cursor_state = Cursor_Input_State.Normal;
			drag_amount = {};
			delta_drag= {};
			drag_target = 0;
	}
}

reset_ctx :: proc(ui_ctx: ^UI_Context, screen_size: [2]int)
{
	clear(&ui_ctx.elements_under_cursor);
	for interaction_type, ui_id in ui_ctx.next_elements_under_cursor
	{
		ui_ctx.elements_under_cursor[interaction_type] = ui_id;
	}
	clear(&ui_ctx.next_elements_under_cursor);
	clear(&ui_ctx.layout_stack);
	base_layout := Layout {
		rect = UI_Rect {
			pos = {0, 0},
			size = screen_size,
		},
		direction = [2]int{0, 1},
	};
	push_layout(ui_ctx, base_layout);
	reset_draw_list(&ui_ctx.ui_draw_list, screen_size);
}

scale_ui_vec_2f :: proc(v: UI_Vec, scale: [2]f32) -> (result: UI_Vec)
{
	result.x = int(f32(v.x) * scale.x);
	result.y = int(f32(v.y) * scale.y);
	return;
}

scale_ui_vec_scal :: proc(v: UI_Vec, scale: f32) -> (result: UI_Vec)
{
	result.x = int(f32(v.x) * scale);
	result.y = int(f32(v.y) * scale);
	return;
}

scale_ui_vec :: proc
{
	scale_ui_vec_scal,
	scale_ui_vec_2f,
};

push_layout :: proc(using ctx: ^UI_Context, layout: Layout)
{
	append(&layout_stack, layout);
}

push_child_layout :: proc(using ctx: ^UI_Context, size: UI_Vec, direction: UI_Vec)
{
	layout := Layout {
		rect = allocate_element_space(ctx, size),
		direction = direction,
	};
	current_layout := current_layout(ctx);
	push_layout(ctx, layout);
}

push_label_layout :: proc(using ctx: ^UI_Context, label: string, height: int, label_size: int)
{
	layout : Layout = current_layout(ctx)^;
	layout.rect = allocate_element_space(ctx, {0, height});
	text_theme := &ctx.current_theme.text.default;
	font := ctx.font_loader.loaded_fonts[text_theme.font_asset];

	line_height := font.line_height;
	render_size := render.get_text_render_size(font, label);
	text(
		text = label, 
		pos = layout.rect.pos + UI_Vec{(label_size - render_size) / 2, height / 2}, 
		alignment = {.Left, .Middle},
		theme = text_theme,
		ctx = ctx);
	layout.pos.x += label_size;
	layout.size.x -= label_size;
	layout.cursor = 0;
	push_layout(ctx, layout);
}

replace_layout :: proc(using ctx: ^UI_Context, layout: Layout)
{
	layout_stack[len(layout_stack)-1] = layout;
}

apply_anchor_padding :: proc(rect: UI_Rect, anchor: Anchor, padding: Padding) -> (result: UI_Rect)
{
	result.pos = rect.pos + scale_ui_vec(rect.size, anchor.min) + padding.top_left;
	result.size = scale_ui_vec(rect.size, anchor.max - anchor.min) - padding.top_left - padding.bottom_right;
	return result;
}

add_content_size_fitter :: proc(
	using ctx: ^UI_Context,
	max_padding: UI_Vec = {},
	directions: bit_set[UI_Direction] = {.Horizontal, .Vertical},
)
{
	append(&content_size_fitters, Content_Size_Fitter{
		rect = {},
		layout_index_in_stack = len(layout_stack)-1,
		max_padding = max_padding,
		directions = directions,
	});
}

pop_layout :: proc(using ctx: ^UI_Context) -> Layout
{
	layout_index := len(layout_stack)-1;
	popped_layout:= pop(&layout_stack);
	if(len(content_size_fitters) > 0)
	{
		content_size_fitter := content_size_fitters[len(content_size_fitters)-1];
		if content_size_fitter.layout_index_in_stack == layout_index
		{
			if UI_Direction.Horizontal in content_size_fitter.directions
			{
				popped_layout.pos.x = content_size_fitter.rect.pos.x;
				popped_layout.size.x = content_size_fitter.rect.size.x;

			}
			if UI_Direction.Vertical in content_size_fitter.directions
			{
				popped_layout.pos.y = content_size_fitter.rect.pos.y;
				popped_layout.size.y = content_size_fitter.rect.size.y;
			}
			popped_layout.rect.size += content_size_fitter.max_padding;
			pop(&content_size_fitters);
		}
	}
	for draw_command in popped_layout.draw_commands
	{
		// TODO : handle anchor and padding properly
		draw_command.rect = popped_layout.rect;
	}
	for content_size_fitter in &content_size_fitters
	{
		content_size_fitter.rect = join_rects(content_size_fitter.rect, popped_layout.rect);
	}
	use_rect_in_layout(ctx, popped_layout.rect);
	allocate_rect(ctx, popped_layout.rect);
	return popped_layout;
}

current_layout :: proc(using ui_ctx: ^UI_Context) -> ^Layout
{
	return &layout_stack[len(layout_stack)-1];
}

current_layout_rect :: proc(using ui_ctx: ^UI_Context) -> UI_Rect
{
	layout := &layout_stack[len(layout_stack)-1];
	cursor_offset := layout.direction * layout.cursor;
	return UI_Rect {
		pos = layout.pos + cursor_offset,
		size = layout.size - cursor_offset,
	};
}

rect :: proc(draw_list: ^Draw_List, rect: UI_Rect, color: Color, corner_radius: int = 0)
{
	uv_rect := util.Rect { size = [2]f32{1, 1}};
	append(draw_list, Rect_Draw_Command{rect = rect, uv_rect= uv_rect, color = color, corner_radius = corner_radius});
}

rect_border :: proc(draw_list: ^Draw_List, rect: UI_Rect, color: Color, thickness: int = 1)
{
	uv_rect:= util.Rect { size = [2]f32{1, 1}};
	append(draw_list, Rect_Draw_Command{
		rect = UI_Rect{linalg.to_int(rect.pos), UI_Vec{rect.size.x, thickness}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});

	append(draw_list, Rect_Draw_Command{
		rect = UI_Rect{rect.pos, UI_Vec{thickness, rect.size.y}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});
	append(draw_list, Rect_Draw_Command{
		rect = UI_Rect{rect.pos + UI_Vec{rect.size.x - thickness, 0}, UI_Vec{thickness, rect.size.y}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});
	append(draw_list, Rect_Draw_Command{
		rect = UI_Rect{rect.pos + UI_Vec{0, rect.size.y - thickness}, UI_Vec{rect.size.x, thickness}},
		uv_rect = uv_rect,
		color = color,
		corner_radius = 0,
	});
}

textured_rect :: proc(
	rect: UI_Rect,
	color: Color,
	sprite: render.Sprite_Handle,
	draw_list: ^Draw_List, 
)
{
	sprite_data: ^render.Sprite = container.handle_get(sprite);
	texture_handle := sprite_data.texture;
	append(draw_list, Rect_Draw_Command{
		rect = rect,
		uv_rect = sprite_data.clip,
		color = color,
		texture = texture_handle,
	});
}

id_from_location :: proc(location := #caller_location, additional_element_index: int = 0) -> UI_ID
{
	file_path := transmute([]byte)location.file_path;
	to_hash := make([]byte, len(file_path) + size_of(int) * 2);
	mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path));
	location_line := location.line;
	additional_element_index : int = additional_element_index;
	mem.copy(&to_hash[len(file_path)], &location_line, size_of(int));
	mem.copy(&to_hash[len(file_path) + size_of(int)], &additional_element_index, size_of(int));
	return UI_ID(hash.fnv32(to_hash));
}

child_id :: proc(id: UI_ID, location := #caller_location, element_index: int = 0) -> UI_ID
{
	return id_from_location(location, element_index ~ int(id));
}

ui_element :: proc {
	ui_element_sized,
	ui_element_placed,
}

ui_element_sized :: proc(
	ctx: ^UI_Context,
	size: UI_Vec,
	interactions: Interactions,
	element_id: UI_ID,
) -> (out_state: Element_State)
{
	return ui_element_placed(ctx, allocate_element_space(ctx, size), interactions, element_id);
}

ui_element_placed :: proc(
	ctx: ^UI_Context,
	rect: UI_Rect,
	interactions: Interactions,
	element_id: UI_ID,
) -> (out_state: Element_State)
{
	ctx.current_element = UI_Element{rect, element_id};
	clip_index := ctx.ui_draw_list.clip_stack[len(ctx.ui_draw_list.clip_stack) - 1];
	clip_rect := ctx.ui_draw_list.clips[clip_index];
	mouse_over :=  ctx.input_state.cursor_pos.x > rect.pos.x 			\
			&& ctx.input_state.cursor_pos.y > rect.pos.y 				\
			&& ctx.input_state.cursor_pos.x < rect.pos.x + rect.size.x	\
			&& ctx.input_state.cursor_pos.y < rect.pos.y + rect.size.y  \
			&& ctx.input_state.cursor_pos.x > clip_rect.pos.x			\
			&& ctx.input_state.cursor_pos.y > clip_rect.pos.y			\
			&& ctx.input_state.cursor_pos.x < clip_rect.pos.x + clip_rect.size.x \
			&& ctx.input_state.cursor_pos.y < clip_rect.pos.y + clip_rect.size.y;
	
	available_interactions: Interactions;
	switch ctx.input_state.cursor_state
	{
		case .Normal:
			available_interactions = {.Hover};
		case .Press:
			available_interactions = {.Press};
		case .Down:
			available_interactions = {.Press};
		case .Drag:
			available_interactions = {.Hover};
			if element_id == ctx.input_state.drag_target do incl(&out_state, Interaction_Type.Drag);
		case .Click_Release:
			available_interactions = {.Click, .Hover};
		case .Drag_Release:
			available_interactions = {.Hover};
	}

	for interaction_type in Interaction_Type 
	{
		if interaction_type in interactions
		{
			under_cursor, has_under_cursor := ctx.elements_under_cursor[interaction_type];
			if has_under_cursor && under_cursor == element_id
			{
				if interaction_type in available_interactions
				{
					incl(&out_state, interaction_type);
				}
				if !mouse_over do ctx.next_elements_under_cursor[interaction_type] = 0;
			}
			if mouse_over
			{
				ctx.next_elements_under_cursor[interaction_type] = element_id;
			}
		}
	}
	layout := current_layout(ctx);
	use_rect_in_layout(ctx, rect);
	return;
}

use_rect_in_layout :: proc(using ctx: ^UI_Context, rect: UI_Rect)
{
	for content_size_fitter in &content_size_fitters
	{
		if content_size_fitter.rect.size.x == 0 || content_size_fitter.rect.size.y == 0
		{
			content_size_fitter.rect = rect;
		}
		else
		{
			content_size_fitter.rect = join_rects(content_size_fitter.rect, rect);
		}
	}
}

element_draw_themed_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding, theme: ^Rect_Theme)
{
	padding_sum := UI_Vec{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := UI_Rect{
		pos = ctx.current_element.pos + scale_ui_vec(ctx.current_element.size, anchor.min) + UI_Vec{anchor.left, anchor.top},
		size = scale_ui_vec(ctx.current_element.size, (anchor.max - anchor.min)) - padding_sum,
	};
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = rect,
		theme = theme^,
	});
}

draw_rect :: proc(ctx: ^UI_Context, rect: UI_Rect, color: Color, corner_radius: f32 = 0)
{
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = rect,
		theme = {
			fill_color = color,
			corner_radius = 10,
			border_color = 0x000000ff,
			border_thickness = 1,
		},
	});
	//append(&ctx.draw_list, Rect_Draw_Command{rect = rect, clip = clip, color = color, corner_radius = corner_radius});
}

element_draw_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding, color: Color, corner_radius: f32 = 0)
{
	padding_sum := UI_Vec{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := UI_Rect{
		pos = ctx.current_element.pos + scale_ui_vec(ctx.current_element.size, anchor.min) + UI_Vec{anchor.left, anchor.top},
		size = scale_ui_vec(ctx.current_element.size, anchor.max - anchor.min) - padding_sum,
	};
	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = rect,
		theme = {
			fill_color = color,
			corner_radius = 10,
			border_color = 0x000000ff,
			border_thickness = 1,
		},
	});
	//append(&ctx.draw_list, Rect_Draw_Command{rect = rect, clip = clip, color = color, corner_radius = corner_radius});
}

element_draw_textured_rect :: proc(
	anchor: Anchor,
	padding: Padding,
	color: Color,
	sprite: render.Sprite_Handle,
	ctx: ^UI_Context,
)
{
	padding_sum := UI_Vec{anchor.right + anchor.left, anchor.bottom + anchor.top};
	rect := UI_Rect{
		pos = ctx.current_element.pos + scale_ui_vec(ctx.current_element.size, anchor.min) + UI_Vec{anchor.left, anchor.top},
		size = scale_ui_vec(ctx.current_element.size, anchor.max - anchor.min) - padding_sum,
	};
	sprite_data: ^render.Sprite = container.handle_get(sprite);
	texture_handle := sprite_data.texture;
	append(&ctx.draw_list, Rect_Draw_Command{
		rect = rect,
		uv_rect = sprite_data.clip,
		color = color,
		texture = texture_handle,
	});
}

text :: proc(
	text: string,
	pos: UI_Vec,
	alignment: Alignment,
	theme: ^Text_Theme,
	ctx: ^UI_Context,
) {
	used_theme := theme == nil ? &ctx.current_theme.text.default : theme;
	font := used_theme.font_asset;
	font_data := ctx.font_loader.loaded_fonts[font];

	alignment_ratios: [2]f32;

	switch alignment.horizontal
	{
		case .Left: alignment_ratios.x = 0;
		case .Center: alignment_ratios.x = 0.5;
		case .Right: alignment_ratios.x = 1;
	}
	vertical_offset : int = 0;
	switch alignment.vertical
	{
		case .Top: vertical_offset = -int(font_data.ascent);
		case .Middle: vertical_offset = -int(font_data.ascent + font_data.descent) / 2;
		case .Bottom: vertical_offset = -int(font_data.descent);
	}
	
	pos_cursor := linalg.to_int(pos) - UI_Vec{int(alignment_ratios.x * f32(render.get_text_render_size(font_data, text))), vertical_offset};
	render.load_glyphs(&ctx.font_atlas, ctx.sprite_table, font_data, text);
	for char in text
	{
		glyph, glyph_found := font_data.glyphs[char]; 
		//assert(glyph_found);
		if glyph_found
		{
			rect := UI_Rect{ pos = pos_cursor + glyph.bearing, size = glyph.size };
			//textured_rect(rect, color, glyph.sprite, &ctx.draw_list);

			glyph_sprite := container.handle_get(glyph.sprite);
			texture := container.handle_get(glyph_sprite.texture);

			add_rect_command(&ctx.ui_draw_list, Rect_Command{
				rect = rect,
				uv_clip = glyph_sprite.clip,
				theme = {
					fill_color = used_theme.color,
				},
				texture_id = texture.bindless_id,
			});
		}
		pos_cursor += glyph.advance / 64;
	}
}

multiline_text :: proc(
	str: string,
	pos: UI_Vec,
	line_size: int,
	alignment: Alignment,
	theme: ^Text_Theme,
	ctx: ^UI_Context,
) {
	font := theme.font_asset;
	font_data := ctx.font_loader.loaded_fonts[font];
	for substring, index in render.split_text_for_render(font_data, str, line_size)
	{
		text(
			text = substring, 
			pos = pos + UI_Vec{0, int(font_data.line_height * f32(index))},
			alignment = {.Left, .Middle},
			theme = theme,
			ctx = ctx);
	}
}

element_draw_text :: proc(
	padding: Padding,
	text: string,
	alignment: Alignment,
	theme: ^Text_Theme,
	ctx: ^UI_Context,
) {
	font := theme.font_asset;
	font_data := ctx.font_loader.loaded_fonts[font];
	pos_cursor := ctx.current_element.pos + padding.top_left + UI_Vec{0, int(font_data.line_height)};
	line_size := int(ctx.current_element.pos.x + ctx.current_element.size.x - pos_cursor.x - padding.bottom_right.x);
	multiline_text(text, pos_cursor, line_size, alignment, theme, ctx);
}

add_and_get_draw_command :: proc(array: ^Draw_List, draw_cmd: $T) -> ^T
{
	added_cmd := util.append_and_get(array);
	added_cmd^ = draw_cmd;
	return cast(^T)added_cmd;
}

// TODO : utility functions to get an anchored / padded sub rect ?
layout_get_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding) -> UI_Rect
{
	layout := current_layout(ctx);
	return {pos = layout.pos, size = layout.size};
}

layout_draw_rect :: proc(ctx: ^UI_Context, anchor: Anchor, padding: Padding, theme: Rect_Theme)
{
	layout := current_layout(ctx);
	layout_rect := layout_get_rect(ctx, anchor, padding);
	new_command := add_rect_command(&ctx.ui_draw_list, Rect_Command {
		rect = UI_Rect{pos = layout.pos, size = layout.size},
		uv_clip = {{0, 0}, {1, 1}},
		theme = theme,
	});

	append(&layout.draw_commands, new_command);
}

default_anchor :: Anchor{{0, 0}, {1, 1}, 0, 0, 0, 0};

drag_box :: proc(
	rect: UI_Rect,
	drag_state: ^Drag_State,

	ui_ctx: ^UI_Context,
	ui_id: UI_ID,
	location := #caller_location,
) -> (state_changed: bool)
{
	ui_id := default_id(ui_id);
	element_state := ui_element(ui_ctx, rect, {.Drag}, ui_id);
	if Interaction_Type.Drag in element_state
	{
		drag_state.drag_offset += ui_ctx.input_state.delta_drag;
		drag_state.drag_last_pos = ui_ctx.input_state.cursor_pos;
		return true;
	}
	return false;
}

allocate_rect :: proc(ui_ctx: ^UI_Context, rect: UI_Rect)
{
	layout := current_layout(ui_ctx);
	if layout.direction.x < 0
	{
		rect_min := rect.pos.x;
		rect_cursor := layout.pos.x + layout.size.x - rect_min;
		if rect_cursor > layout.cursor do layout.cursor = rect_cursor;
	}
	else if layout.direction.x > 0
	{
		rect_max := rect.pos.x + rect.size.x;
		rect_cursor := rect_max - layout.pos.x;
		if rect_cursor > layout.cursor do layout.cursor = rect_cursor;
	}
	if layout.direction.y < 0
	{
		rect_min := rect.pos.y;
		rect_cursor := layout.pos.y + layout.size.y - rect_min;
		if rect_cursor > layout.cursor do layout.cursor = rect_cursor;
	}
	else if layout.direction.y > 0
	{
		rect_max := rect.pos.y + rect.size.y;
		rect_cursor := rect_max - layout.pos.y;
		if rect_cursor > layout.cursor do layout.cursor = rect_cursor;
	}
}

allocate_element_space :: proc(ui_ctx: ^UI_Context, size: UI_Vec) -> UI_Rect
{
	layout := current_layout(ui_ctx);
	result := UI_Rect{layout.pos + layout.direction * layout.cursor, size};
	if layout.direction.x < 0
	{
		result.pos.x = layout.pos.x + layout.size.x - layout.cursor - size.x;
	}
	if layout.direction.y < 0
	{
		result.pos.y = layout.pos.y + layout.size.y - layout.cursor - size.y;
	}
	if size.x == 0
	{
		result.size.x = layout.size.x - layout.direction.x * layout.cursor;
	}
	if size.y == 0
	{
		result.size.y = layout.size.y - layout.direction.y * layout.cursor;
	}
	layout.cursor += linalg.vector_dot(result.size, layout.direction);
	use_rect_in_layout(ui_ctx, result);
	return result;
}

button :: proc{ button_themed, button_placed };

button_themed :: proc(
	using ui_ctx: ^UI_Context,
	label: string,
	size: UI_Vec,
	theme: ^Button_Theme = nil,

	ui_id: UI_ID = 0,
	location := #caller_location,
) -> (clicked: bool)
{
	button_theme := theme;
	if theme == nil do button_theme = &ui_ctx.current_theme.button;
	ui_id := default_id(ui_id, location);
	layout := current_layout(ui_ctx);
	allocated_space := allocate_element_space(ui_ctx, size);
	element_state := ui_element(ui_ctx, allocated_space, {.Hover, .Press, .Click}, ui_id);
	color: Color;

	used_theme: Rect_Theme;
	using button_theme;
	if Interaction_Type.Press in element_state
	{
		used_theme = clicked_theme;
	}
	else if Interaction_Type.Hover in element_state 
	{
		used_theme = hovered_theme;
	}
	else
	{
		used_theme = default_theme;
	}
	element_draw_themed_rect(ui_ctx, {{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, &used_theme);
	text_theme := &ui_ctx.current_theme.text.default;
	font := ui_ctx.font_loader.loaded_fonts[text_theme.font_asset];
	text(label, allocated_space.pos + allocated_space.size / 2, {.Center, .Middle}, text_theme, ui_ctx);
	
	return Interaction_Type.Click in element_state;
}

button_placed :: proc(
	using ui_ctx: ^UI_Context,
	label: string,
	rect: UI_Rect,
	theme: ^Button_Theme,

	ui_id: UI_ID = 0,
	location := #caller_location,
) -> (clicked: bool)
{
	button_theme := theme;
	if theme == nil do button_theme = &ui_ctx.current_theme.button;
	ui_id := default_id(ui_id, location);
	element_state := ui_element(ui_ctx, rect, {.Hover, .Press, .Click}, ui_id);
	color: Color;

	used_theme: Rect_Theme;
	using button_theme;
	if Interaction_Type.Press in element_state
	{
		used_theme = clicked_theme;
	}
	else if Interaction_Type.Hover in element_state 
	{
		used_theme = hovered_theme;
	}
	else
	{
		used_theme = default_theme;
	}
	element_draw_themed_rect(ui_ctx, {{0, 0}, {1, 1}, 0, 0, 0, 0}, {}, &used_theme);
	text_theme := &ui_ctx.current_theme.text.default;
	font := ui_ctx.font_loader.loaded_fonts[text_theme.font_asset];
	text(label, rect.pos + rect.size / 2, {.Center, .Middle}, text_theme, ui_ctx);
	
	return Interaction_Type.Click in element_state;
}

vsplit :: proc{
	vsplit_layout_ratio,
	vsplit_layout_weights,
};

vsplit_layout_ratio :: proc(using ui_ctx: ^UI_Context, split_ratio: f32) -> [2]UI_Rect
{
	rect := current_layout_rect(ui_ctx);
	left_split_width := int(f32(rect.size.x) * split_ratio);
	out_layouts: [2]UI_Rect = {
		{
			pos = rect.pos,
			size = [2]int{left_split_width, rect.size.y},
		},
		{
			pos = [2]int{rect.pos. x + left_split_width, rect.pos.y},
			size = [2]int{rect.size.x - left_split_width, rect.size.y},
		},
	};
	return out_layouts;
}

vsplit_layout_weights :: proc(using ui_ctx: ^UI_Context, split_weights: []f32, spacing: int = 0, allocator := context.allocator) -> []UI_Rect
{
	rect := current_layout_rect(ui_ctx);

	result := make([]UI_Rect, len(split_weights));

	weights_sum: f32;
	for i in 0..<len(split_weights)
	{
		weights_sum += split_weights[i];
	}

	pos_cursor := rect.pos;
	available_width := f32(rect.size.x - spacing * (len(split_weights) - 1));
	for i in 0..<len(split_weights)
	{
		width := int(available_width * split_weights[i] / weights_sum);
		result[i] = UI_Rect {
			pos = pos_cursor,
			size = {width, rect.size.y},
		};
		pos_cursor.x += width + spacing;
	}
	return result;
}

round_corner_subdivisions :: 3;

render_draw_list :: proc(draw_list: ^Draw_List, render_system: ^render.Sprite_Render_System)
{

	push_rect_data :: proc(render_system: ^render.Sprite_Render_System, rect: UI_Rect, clip: UV_Rect, color: render.Color)
	{
		vertices: [dynamic]render.Sprite_Vertex_Data;
		indices: [dynamic]u32;
		quad_index_list := [?]u32{0, 1, 2, 0, 2, 3};
		start_index := u32(len(vertices));
		pos := linalg.to_f32(rect.pos);
		size := linalg.to_f32(rect.size);
		vertice: render.Sprite_Vertex_Data = {pos, clip.pos, color};
		append(&vertices, vertice);
		vertice.pos.x = pos.x + size.x;
		vertice.uv.x = clip.pos.x + clip.size.x;
		append(&vertices, vertice);
		vertice.pos.y = pos.y + size.y;
		vertice.uv.y = clip.pos.y + clip.size.y;
		append(&vertices, vertice);
		vertice.pos.x = pos.x;
		vertice.uv.x = clip.pos.x;
		append(&vertices, vertice);
		for index_offset in quad_index_list
		{
			append(&indices, start_index + index_offset);
		}
		render.push_mesh_data(&render_system.buffer, vertices[:], indices[:]);
		clear(&vertices);
		clear(&indices);
	}

	push_corner_data :: proc(render_system: ^render.Sprite_Render_System, pos: UI_Vec, dir: UI_Vec, color: Color)
	{
		vertices: [dynamic]render.Sprite_Vertex_Data;
		indices: [dynamic]u32;
		f_pos := linalg.to_f32(pos);
		vertice: render.Sprite_Vertex_Data = {f_pos, {}, color};
		append(&vertices, vertice);
		for i in 0..round_corner_subdivisions
		{
			angle := f32(i) / f32(round_corner_subdivisions) * math.PI / 2;
			vertice.pos = f_pos + [2]f32{f32(dir.x) * math.cos(angle), f32(dir.y) * math.sin(angle)};
			append(&vertices, vertice);
		}
		for i in 0..<round_corner_subdivisions
		{
			append(&indices, 0);
			append(&indices, u32(i) + 1);
			append(&indices, u32(i) + 2);
		}
		render.push_mesh_data(&render_system.buffer, vertices[:], indices[:]);
		clear(&vertices);
		clear(&indices);
	}

	for draw_cmd in draw_list
	{
		switch cmd_data in draw_cmd
		{
			case Clip_Draw_Command:
				
			case Rect_Draw_Command:
				render.use_texture(render_system, cmd_data.texture);
				if cmd_data.corner_radius > 0
				{
					using cmd_data;
					push_rect_data(
						render_system, 
						{
							pos + UI_Vec{0, corner_radius},
							UI_Vec{corner_radius, size.y - 2 * corner_radius},
						}, 
						cmd_data.uv_rect, 
						cmd_data.color,
					);
					push_rect_data(
						render_system, 
						{
							pos + UI_Vec{corner_radius, 0},
							UI_Vec{size.x - corner_radius * 2, size.y},
						}, 
						uv_rect, 
						cmd_data.color,
					);
					push_rect_data(
						render_system, 
						{
							pos + UI_Vec{size.x - corner_radius, corner_radius}, 
							UI_Vec{corner_radius, size.y - 2 * corner_radius},
						}, 
						cmd_data.uv_rect, 
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + UI_Vec{corner_radius, corner_radius},
						UI_Vec{-corner_radius, -corner_radius},
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + UI_Vec{cmd_data.size.x - corner_radius, corner_radius},
						UI_Vec{corner_radius, -corner_radius},
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + UI_Vec{corner_radius, cmd_data.size.y - corner_radius},
						UI_Vec{-corner_radius, corner_radius},
						cmd_data.color,
					);
					push_corner_data(
						render_system,
						pos + cmd_data.size - UI_Vec{corner_radius, corner_radius},
						UI_Vec{corner_radius, corner_radius},
						cmd_data.color,
					);
				}
				else
				{
					push_rect_data(render_system, {cmd_data.pos, cmd_data.size}, cmd_data.uv_rect, cmd_data.color);
				}
		}
	}
	clear(draw_list);
}

