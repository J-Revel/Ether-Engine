package imgui

import "core:strings"
import "core:math/linalg"
import "core:fmt"

import "../util"
import platform_layer "../platform_layer/base"

font_atlas_size: [2]int = {1024, 1024}

add_rect_command :: proc(using draw_list: ^platform_layer.Command_List, rect_command: platform_layer.Rect_Command)
{
	append(&commands, rect_command)
}

add_glyph_command :: proc(using draw_list: ^platform_layer.Command_List, glyph_command: platform_layer.Glyph_Command)
{
	append(&commands, glyph_command)
}

reset_draw_list :: proc(using draw_list: ^platform_layer.Command_List, viewport: platform_layer.I_Rect)
{
	clear(&clips)
	append(&clips, viewport)
	clear(&draw_list.commands)
}