package custom_imgui;

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

init_ctx :: proc(ui_ctx: ^UI_Context, sprite_database: ^render.Sprite_Database)
{
	ui_ctx.sprite_table = &sprite_database.sprites;
	render.init_font_atlas(&sprite_database.textures, &ui_ctx.font_loader.font_atlas); 
	init_renderer(&ui_ctx.renderer);
	
	error: Theme_Load_Error;
	ui_ctx.current_theme, error = load_theme("config/ui/base_theme.json");
log.info(ui_ctx.current_theme);
	fonts := [?]render.Font_Asset{
		ui_ctx.current_theme.text.default.font_asset, 
		ui_ctx.current_theme.text.title.font_asset,
	};
	log.info("Fonts to load :", fonts);
	load_fonts(&ui_ctx.font_loader, fonts[:]);
	base_font := ui_ctx.loaded_fonts[ui_ctx.current_theme.text.default.font_asset];
	ui_ctx.editor_config.line_height = int(base_font.line_height) + 4;
	if error != nil do log.info("Error loading theme :", error);

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

reset_ctx :: proc(ctx: ^UI_Context, screen_size: [2]int)
{
	clear(&ctx.elements_under_cursor);
	clear(&ctx.interactive_elements);
	clear(&ctx.layout_stack);
	clear(&ctx.hierarchy);
	clear(&ctx.hierarchy_data);
	clear(&ctx.element_stack);

	reset_draw_list(&ctx.ui_draw_list, screen_size);
}

current_layout :: proc(using ctx: ^UI_Context) -> ^Layout
{
	assert(len(layout_stack) > 0);
	return &layout_stack[len(layout_stack)-1];
}

push_layout :: proc(using ctx: ^UI_Context, layout_callbacks: Layout_Callbacks)
{
	element: Element_ID = len(element_stack) > 0 ? element_stack[len(element_stack)-1] : -1;
	append(&layout_stack, Layout{element = element, callbacks = layout_callbacks});
}

pop_layout :: proc(using ctx: ^UI_Context)
{
	assert(len(layout_stack) > 0);
	popped_layout := layout_stack[len(layout_stack)-1];
	popped_layout.place_elements_function(ctx, &popped_layout);
	pop(&layout_stack);
}

allocate_element :: proc(ctx: ^UI_Context, preferred_size: UI_Vec, id: UID) -> Element_ID 
{
	layout := current_layout(ctx);
	allocated_size := layout.allocate_element_size(ctx, layout, preferred_size);
	element_rect := Child_Rect{
		rect = UI_Rect{{0, 0}, allocated_size },
	};
	append(&ctx.hierarchy, Hierarchy_Element{element_rect, layout.element, id});
	append(&ctx.hierarchy_data, Hierarchy_Element_Data{preferred_size});
	hierarchy_index := len(ctx.hierarchy) - 1;
	append(&layout.children, Element_ID(hierarchy_index));
	return Element_ID(hierarchy_index);
}

update_interactions :: proc(using ctx: ^UI_Context, hierarchy_rects: []UI_Rect) -> map[Interaction_Type]UID
{
	result: map[Interaction_Type]UID;
	for interaction_type, elements in interactive_elements
	{
		for i := len(elements)-1; i >= 0; i -= 1
		{
			if point_in_rect(input_state.cursor_pos, hierarchy_rects[i])
			{
				result[interaction_type] = hierarchy[i].id;
				break;
			}
		}
	}
	return result;
}

compute_hierarchy_positions :: proc(hierarchy: ^Hierarchy, screen_rect: UI_Rect, allocator := context.allocator) -> []UI_Rect
{
	hierarchy_rects := make([]UI_Rect, len(hierarchy), allocator);
	for i in 0..<len(hierarchy)
	{
		parent_index := hierarchy[i].parent;
		parent_rect := parent_index < 0 ? screen_rect : hierarchy_rects[parent_index];
		hierarchy_rects[i] = compute_child_rect(parent_rect, hierarchy[i].rect);
	}
	return hierarchy_rects;
}


/* TODO
	button implementation (simple rect for now)
	=> add a UI_Element with (0, 0) local position and the expected rect
*/
button :: proc(
	ctx: ^UI_Context,
	size: UI_Vec,
	theme: ^Button_Theme = nil,
	ui_id: UID = 0,
	location := #caller_location,
) -> (clicked: bool)
{
	used_theme := theme == nil ? &ctx.current_theme.button : theme;
	ui_id := default_id(ui_id, location);
	element := allocate_element(ctx, size, ui_id);

	add_rect_command(&ctx.ui_draw_list, Rect_Command{
		rect = filling_child_rect(),
		theme = used_theme^.default_theme,
	}, element);

	return false;
}

basic_layout_allocate_element :: proc(ctx: ^UI_Context, layout: ^Layout, required_size: UI_Vec) -> UI_Vec
{
	log.info("allocate element", required_size);
	return required_size;
}

basic_layout_place_elements :: proc(ctx: ^UI_Context, layout: ^Layout)
{
	cursor := 0;
	log.info("place elements");
	for element in &layout.children
	{
		hierarchy_element := &ctx.hierarchy[int(element)];
		element_data := &ctx.hierarchy_data[int(element)];
		hierarchy_element.rect.rect = UI_Rect {pos = {0, cursor}, size = element_data.preferred_size};
		cursor += element_data.preferred_size.y;
	}
	if layout.element >= 0 do ctx.hierarchy_data[layout.element].preferred_size.y = cursor;
}
