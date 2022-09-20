package imgui_sdl

// import imgui ".."
// import "core:math/linalg"
// import "core:math"
// import platform_layer "../../platform_layer/base"


// sdl_renderer: ^sdl.Renderer

// init_renderer :: proc(window: platform_layer.Window_Handle, renderer: ^imgui.Renderer) -> bool {
// 	sdl_window: ^sdl.Window = cast(^sdl.Window)platform_layer.instance.get_window_raw_ptr(window)
// 	sdl_renderer = sdl.CreateRenderer(sdl_window, -1, sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC)
// 	sdl.SetRenderDrawBlendMode(sdl_renderer, .BLEND)
// 	return true
// }

// render_draw_commands :: proc(
// 	render_system: ^imgui.Renderer,
// 	draw_list: ^imgui.Command_List,
// ) {
// 	sdl.RenderSetClipRect(sdl_renderer, cast(^sdl.Rect)&draw_list.clips[0])
// 	sdl.SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255)
// 	sdl.RenderClear(sdl_renderer)
// 	src_rect := sdl.Rect {
// 		0, 0, 1024, 1024
// 	}
// 	dst_rect := sdl.Rect {
// 		0, 0, 1024, 1024
// 	}
// 	for command in draw_list.commands {
// 		switch c in command {
// 			case imgui.Rect_Command:
// 				color := c.theme.color
// 				r, g, b, a: u8
// 				a = u8(c.color % 256)
// 				b = u8((c.color >> 8) % 256)
// 				g = u8((c.color >> 16) % 256)
// 				r = u8((c.color >> 24) % 256)
// 				sdl.SetRenderDrawColor(sdl_renderer, r, g, b, a)
// 				rect := transmute(sdl.Rect)c.rect
// 				sdl.RenderSetClipRect(sdl_renderer, cast(^sdl.Rect)&draw_list.clips[c.clip_index])
// 				sdl.RenderFillRect(sdl_renderer, &rect)

// 			case imgui.Glyph_Command:
// 				color := c.color
// 				r, g, b, a: u8
// 				a = u8(c.color % 256)
// 				b = u8((c.color >> 8) % 256)
// 				g = u8((c.color >> 16) % 256)
// 				r = u8((c.color >> 24) % 256)
// 				sdl.SetRenderDrawColor(sdl_renderer, r, g, b, a)
// 				src_rect := sdl.Rect {
// 					i32(c.uv_rect.pos.x * 1024),
// 					i32(c.uv_rect.pos.y * 1024),
// 					i32(c.uv_rect.size.x * 1024),
// 					i32(c.uv_rect.size.y * 1024),
// 				}
// 				dst_rect := sdl.Rect {
// 					i32(c.rect.pos.x), i32(c.rect.pos.y),
// 					i32(c.rect.size.x), i32(c.rect.size.y),
// 				}
// 				sdl.RenderCopy(sdl_renderer, textures[c.texture_id], &src_rect, &dst_rect)
// 		}
// 	}
// 	sdl.RenderPresent(sdl_renderer)
// }

// free_renderer :: proc(renderer: ^imgui.Renderer) {
// 	sdl.DestroyRenderer(sdl_renderer)
// }
