package imgui

import "core:hash"
import "core:mem"
import "core:strings"
import "core:math/linalg"
import "core:math"
import "core:fmt"
import "../util"
import "../input"
import platform_layer "../platform_layer/base"

editor_font: platform_layer.Font_Handle

I_Rect :: util.Rect(i32)
F_Rect :: util.Rect(f32)

init_ui_state :: proc(using ui_state: ^UI_State, viewport: I_Rect) {
	
	reset_draw_list(&command_list, viewport)
	append(&clip_stack, 0)

	// fontinfo: stb_tt.fontinfo
	editor_font = platform_layer.instance.load_font("resources/fonts/Roboto-Regular.ttf", context.temp_allocator)
}

gen_uid :: proc(location := #caller_location, additional_index: int = 0) -> UID {
    to_hash := make([]byte, len(transmute([]byte)location.file_path) + size_of(i32) * 2)
	mem.copy(&to_hash[0], strings.ptr_from_string(location.file_path), len(location.file_path))
	location_line := location.line
	mem.copy(&to_hash[len(location.file_path)], &location_line, size_of(i32))
	additional_index_cpy := additional_index
	mem.copy(&to_hash[len(location.file_path) + size_of(i32)], &additional_index_cpy, size_of(i32))
    return UID(hash.djb2(to_hash))
}

themed_rect :: proc(using ui_state: ^UI_State, rect: I_Rect, theme: ^platform_layer.Rect_Theme, block_hover: bool = false)
{
	if block_hover && util.is_in_rect(rect, linalg.to_i32(input_state.mouse_pos)) {
		next_hovered = 0
	}
	add_rect_command(&ui_state.command_list, platform_layer.Rect_Command {
		rect = rect,
		theme = theme^,
		clip_index = clip_stack[len(clip_stack) - 1],
	})
}

button :: proc(using ui_state: ^UI_State, rect: I_Rect, theme: ^Button_Theme, uid: UID) -> (out_state: Button_State) {
	displayed_theme := &theme.default_theme
	out_state = input.Key_State_Up

	mouse_pos := linalg.to_i32(input_state.mouse_pos)
    if util.is_in_rect(rect, mouse_pos) && util.is_in_rect(get_clip(ui_state), mouse_pos) {
		next_hovered = uid
		out_state = input.Key_State_Up
		if hovered_element == uid {
			displayed_theme = &theme.hovered_theme
		 	if input.get_key_state(ui_state.input_state, .MOUSE_LEFT) == input.Key_State_Pressed {
				dragged_element = uid
				out_state = input.Key_State_Pressed
			}
		}
	}
	if dragged_element == uid {
		if out_state != input.Key_State_Pressed {
			out_state = input.Key_State_Down
			if input.get_key_state(ui_state.input_state, .MOUSE_LEFT) == input.Key_State_Released {
				out_state = input.Key_State_Released
				dragged_element = 0
			}
		}
		displayed_theme = &theme.clicked_theme
	}
	themed_rect(ui_state, rect, displayed_theme)
	return
}

slider :: proc(using ui_state: ^UI_State, rect: I_Rect, value: ^$T, min: T, max: T, theme: ^Slider_Theme, uid: UID) -> bool {
	themed_rect(ui_state, rect, &theme.background_theme, true)
	cursor_rect := rect
	cursor_rect.size.y = theme.cursor_height

	available_height := rect.size.y - theme.cursor_height

	display_value := value^
	dragged_data := cast(^Default_Dragged_Data(T))dragged_element_data
	value_changed := false
	
	if dragged_element == uid {
		mouse_delta := linalg.to_i32(input_state.mouse_pos) - dragged_data.drag_start_pos
		delta_value := T(mouse_delta.y) * (max - min) / T(available_height)
		
		display_value = math.clamp(dragged_data.drag_start_value - delta_value, math.min(min, max), math.max(min, max))
		if value^ != display_value do value_changed = true
		value^ = display_value
	}
	cursor_rect.pos.y += i32(f32(available_height) * (1 - f32((display_value - min)) / f32((max - min))))
	switch button(ui_state, cursor_rect, &theme.cursor_theme, uid) {
		case input.Key_State_Pressed:
			new_dragged_data := new(Default_Dragged_Data(T))
			new_dragged_data.drag_start_pos = linalg.to_i32(input_state.mouse_pos)
			new_dragged_data.drag_start_value = value^
			dragged_element_data = new_dragged_data
		case input.Key_State_Released:
			free(dragged_data)
			dragged_element_data = nil
	}
	return value_changed
}

scrollbar :: proc(
	using ui_state: ^UI_State,
	bar_rect: I_Rect,
	content_size: i32,
	display_size: i32,
	scroll_pos: ^i32,
	theme: ^Slider_Theme,
	uid: UID,
) {
	slider_theme: Slider_Theme = theme^
	slider_theme.cursor_height = bar_rect.size.y * display_size / content_size 
	slider(ui_state, bar_rect, scroll_pos, content_size - display_size, 0, &slider_theme, uid)
}

scrollzone_start :: proc (
	using ui_state: ^UI_State,
	rect: I_Rect,
	content_size: i32,
	scroll_pos: ^i32,
	theme: ^Scrollzone_Theme,
	uid: UID,
) -> (out_content_rect: I_Rect) {
	bar_rect := rect
	bar_rect.pos.x = bar_rect.pos.x + bar_rect.size.x - theme.bar_thickness
	bar_rect.size.x = theme.bar_thickness
	scrollbar(ui_state, bar_rect, content_size, rect.size.y, scroll_pos, &theme.slider_theme, uid)
	background_rect := rect
	background_rect.size.x -= theme.bar_thickness
	themed_rect(ui_state, background_rect, &theme.background_theme)
	rest_rect_theme: platform_layer.Rect_Theme = {
		color = 0x883333ff,
	}
	test_rect : I_Rect = {
		pos = rect.pos - [2]i32{0, scroll_pos^},
		size = [2]i32{rect.size.x - theme.bar_thickness, content_size}
	}
	push_clip(ui_state, rect)
	themed_rect(ui_state, test_rect, &rest_rect_theme)
	out_content_rect = test_rect
	return out_content_rect
}

scrollzone_end :: proc(using ui_state: ^UI_State) {
	pop_clip(ui_state)
}

window_start :: proc (
	using ui_state: ^UI_State,
	rect: ^I_Rect,
	content_size: i32,
	scroll_pos: ^i32,
	theme: ^Window_Theme,
	uid: UID,
) -> (out_content_rect: I_Rect) {
	title_text := "popup window title"
	header_rect, scrollzone_rect := util.rect_vsplit(rect^, theme.header_thickness)
	header_uid := gen_uid() ~ uid
	dragged_data := cast(^Default_Dragged_Data([2]i32))dragged_element_data
	if dragged_element == header_uid {
		mouse_delta := linalg.to_i32(input_state.mouse_pos) - dragged_data.drag_start_pos
		
		rect.pos = dragged_data.drag_start_value + mouse_delta
	}
	switch button(ui_state, header_rect, &theme.header_theme, header_uid) {
		case input.Key_State_Pressed:
			new_dragged_data := new(Default_Dragged_Data([2]i32))
			new_dragged_data.drag_start_pos = linalg.to_i32(input_state.mouse_pos)
			new_dragged_data.drag_start_value = rect.pos
			dragged_element_data = new_dragged_data
		case input.Key_State_Released:
			free(dragged_data)
			dragged_element_data = nil
	}

	default_font := &ui_state.fonts["default"]
	text_theme : Text_Theme = { 
    	font = "default", 
    	size = 20,
    	color = 0xffffffff,
	}

	text_block_theme := Text_Block_Theme {
		text_theme,
		{0.5, 0.5}
	}

    // text_block(ui_state, header_rect, title_text, &text_block_theme)

	return scrollzone_start(ui_state, scrollzone_rect, content_size, scroll_pos, &theme.scrollzone_theme, gen_uid() ~ uid)
}

window_end :: proc(using ui_state: ^UI_State) {
	pop_clip(ui_state)
}

render_frame :: proc(using ui_state: ^UI_State, viewport: I_Rect) {
	render_system.render_draw_commands(&ui_state.render_system, &command_list)
	reset_draw_list(&command_list, viewport)
	clear(&clip_stack)
	append(&clip_stack, 0)
	hovered_element = next_hovered
	next_hovered = 0
	switch input.get_key_state(ui_state.input_state, .MOUSE_LEFT)
	{
		case input.Key_State_Released:
			dragged_element = 0
		case input.Key_State_Pressed:
			focused_element = next_focused
	}
	next_focused = 0
	mouse_pos := linalg.to_i32(input_state.mouse_pos)
}

push_clip :: proc(using ui_state: ^UI_State, clip: I_Rect) {
	append(&command_list.clips, clip)
	clip_index := i32(len(command_list.clips) - 1)
	append(&clip_stack, clip_index)
}

pop_clip :: proc(using ui_state: ^UI_State) {
	pop(&clip_stack)
}

get_clip :: proc (using ui_state: ^UI_State) -> I_Rect {
	return command_list.clips[clip_stack[len(clip_stack) - 1]]
}

compute_text_size :: proc(font: platform_layer.Font_Handle, text: string, scale: f32) -> [2]i32{
	glyph_cursor := [2]f32{0, 0}
	display_scale := scale / f32(font.render_height)
	
	for character in text {
        glyph := font.glyph_data[character]
        
        glyph_cursor.x += f32(glyph.advance) * font.render_scale * display_scale
    }
	return [2]i32{ i32(glyph_cursor.x) + 1, i32(f32(font.ascent + font.descent) * font.render_scale * display_scale) }
}

get_text_display_scale :: proc(using ui_state: ^UI_State, theme: ^Text_Theme) -> f32 {
	font := &fonts[theme.font]
	return theme.size * font.render_height
}

compute_text_rect :: proc(font: platform_layer.Font_Handle, text: string, render_pos: [2]i32, scale: f32) -> I_Rect {
	glyph_cursor := [2]f32{0, 0}
	display_scale := scale / f32(font.render_height)
	
	for character in text {
        glyph := font.glyph_data[character]
        
        glyph_cursor.x += f32(glyph.advance) * font.render_scale * display_scale
    }
	size := [2]i32{ i32(glyph_cursor.x) + 1, i32(f32(font.ascent - font.descent) * font.render_scale * display_scale) }
	pos := render_pos + [2]i32{0, -i32(f32(font.ascent) * font.render_scale * display_scale) }
	return I_Rect{pos, size}
}

compute_text_render_buffer :: proc(using ui_state: ^UI_State, text: string, theme: ^Text_Theme, allocator := context.allocator) -> Text_Render_Buffer {
	glyph_cursor: [2]f32
	font := &fonts[theme.font]
	atlas_size := font.atlas_size
	result : Text_Render_Buffer = {
		theme = theme,
		text = text,
		render_rects = make([]F_Rect, len(text), allocator),
		caret_positions = make([][2]f32, len(text)+1, allocator),
	}
	bounding_rect: F_Rect
	for character, index in text {
        glyph := font.glyph_data[character]
		display_scale := theme.size / f32(font.render_height)
		result.render_rects[index] = F_Rect{
			pos = glyph_cursor + linalg.to_f32(glyph.offset) * display_scale,
            size = linalg.to_f32(glyph.rect.size) * display_scale,
		}
		result.caret_positions[index] = glyph_cursor
		bounding_rect = util.union_bounding_rect(bounding_rect, result.render_rects[index])

        glyph_cursor.x += f32(glyph.advance) * font.render_scale * display_scale
    }
    result.caret_positions[len(result.caret_positions)-1] = glyph_cursor
    result.bounding_rect = util.round_rect_to_i32(bounding_rect)
    return result
}

place_text_buffer_in_rect :: proc(using ui_state: ^UI_State, text_buffer: ^Text_Render_Buffer, rect: I_Rect, alignment: [2]f32) {
	available_size := rect.size - text_buffer.bounding_rect.size
	text_buffer.offset = linalg.to_f32(rect.pos) + linalg.to_f32(available_size) * alignment - linalg.to_f32(text_buffer.bounding_rect.pos)
}

get_caret_pos :: proc(text_buffer: ^Text_Render_Buffer, caret_index: int) -> [2]f32 {
	return text_buffer.caret_positions[caret_index] + text_buffer.offset
}

get_character_at_position :: proc(text_buffer: ^Text_Render_Buffer, position: [2]f32) -> i32 {
	closest_manhattan_distance := max(f32)
	closest_index : i32 = 0
	// log.info(position, text_buffer.offset)
	test_value :: struct {
		position : [2]f32 ,
		distance : f32,
	}
	test : []test_value = make([]test_value, len(text_buffer.caret_positions))
	for caret_position, index in text_buffer.caret_positions {
		manhattan_distance := math.abs(position.x - (caret_position.x + text_buffer.offset.x)) + math.abs(position.y - (caret_position.y + text_buffer.offset.y))
		test[index] = {caret_position + text_buffer.offset, manhattan_distance}
		if manhattan_distance < closest_manhattan_distance {
			closest_manhattan_distance = manhattan_distance
			closest_index = i32(index)
		}
	}
	return closest_index
}


render_text_buffer :: proc(using ui_state: ^UI_State, using render_buffer: ^Text_Render_Buffer)
{
	font := &fonts[theme.font]
	atlas_size := font.atlas_size
	for character, index in text {
        glyph := font.glyph_data[character]
		display_scale := theme.size / f32(font.render_height)
        add_glyph_command(&ui_state.command_list, Glyph_Command {
            rect = {
            	pos = render_rects[index].pos + offset,
            	size = render_rects[index].size,
        	},
            uv_rect = {
            	pos = linalg.to_f32(glyph.rect.pos) / linalg.to_f32(atlas_size),
            	size = linalg.to_f32(glyph.rect.size) / linalg.to_f32(atlas_size),
        	},
            color = 0xffffffff,
            threshold = f32(180)/f32(255),
            texture_id = font.atlas_texture,
            clip_index = clip_stack[len(clip_stack) - 1],
        })
    }
}


compute_text_block_rect :: proc(using ui_state: ^UI_State, rect: I_Rect, text: string, theme: ^Text_Block_Theme) -> I_Rect {
	text_rect := compute_text_rect(&fonts[theme.text_theme.font], text, rect.pos, theme.text_theme.size)
	available_size := rect.size - text_rect.size
	offset := linalg.to_f32(available_size) * theme.alignment
	return I_Rect{linalg.to_i32(linalg.to_f32(text_rect.pos) + offset - linalg.to_f32(text_rect.pos - rect.pos)), text_rect.size}
}

text_field :: proc(using ui_state: ^UI_State, rect: I_Rect, value: string, caret_position: ^i32, theme: ^Text_Field_Theme, uid: UID, allocator := context.allocator) -> (new_value: string) {
	switch button(ui_state, rect, &theme.background_theme, uid) {
		case input.Key_State_Pressed:
			next_focused = uid
	}
	text_render_buffer := compute_text_render_buffer(ui_state, value, &theme.text_theme, context.temp_allocator)
	place_text_buffer_in_rect(ui_state, &text_render_buffer, rect, theme.text_theme.alignment)
	render_text_buffer(ui_state, &text_render_buffer)
	caret_pos := get_caret_pos(&text_render_buffer, int(caret_position^))
	font := &fonts[theme.text_theme.font]
	ascent := font.ascent
	descent := font.descent
	display_scale := theme.text_theme.size / f32(font.render_height)
	// caret_rect := F_Rect { caret_pos.pos + {caret_pos.size.x - f32(theme.caret_thickness) / 2, 0}, {f32(theme.caret_thickness), caret_pos.size.y}}
	// themed_rect(ui_state, util.round_rect_to_i32(caret_rect), theme.caret_theme)
	if focused_element == uid {
		themed_rect(ui_state, I_Rect{linalg.to_i32(caret_pos) - [2]i32{0, i32(f32(ascent) * display_scale * font.render_scale)} , {theme.caret_thickness, i32(f32(ascent - descent) * display_scale * font.render_scale)}}, &theme.caret_theme)

		if input.get_key_state(ui_state.input_state, .RIGHT) == input.Key_State_Pressed do caret_position^ += 1
		if input.get_key_state(ui_state.input_state, .LEFT) == input.Key_State_Pressed do caret_position^ -= 1
		if input.get_key_state(ui_state.input_state, .BACKSPACE) == input.Key_State_Pressed {
			new_value_builder: strings.Builder
			fmt.sbprint(&new_value_builder, value[0:caret_position^-1])
			fmt.sbprint(&new_value_builder, value[caret_position^:])
			caret_position^ -= 1
			return strings.to_string(new_value_builder)
		}

		if input.get_key_state(ui_state.input_state, .MOUSE_LEFT) == input.Key_State_Down {
			caret_position^ = get_character_at_position(&text_render_buffer, linalg.to_f32(ui_state.input_state.mouse_pos))
		}
		if len(ui_state.input_state.text_input) > 0 {
			// log.info(ui_state.input_state.text_input)
			new_value_builder: strings.Builder
			fmt.sbprint(&new_value_builder, value[0:caret_position^])
				fmt.sbprint(&new_value_builder, ui_state.input_state.text_input)
			fmt.sbprint(&new_value_builder, value[caret_position^:])
			caret_position^ += i32(len(ui_state.input_state.text_input))
			return strings.to_string(new_value_builder)
		}
	}

	caret_position^ = math.clamp(caret_position^, 0, i32(len(value)))

	
	return value
}