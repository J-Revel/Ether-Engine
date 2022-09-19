package imgui_sdl

import imgui ".."
import sdl "vendor:sdl2"
import "core:log"
import "core:math/linalg"
import "core:math"
import "../../display"


sdl_renderer: ^sdl.Renderer
textures: map[imgui.Texture_Handle]^sdl.Texture
next_handle: imgui.Texture_Handle

init_renderer :: proc(window: ^display.Render_Window, renderer: ^imgui.Renderer) -> bool {
	sdl_renderer = sdl.CreateRenderer(window.sdl_window, -1, sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC)
	sdl.SetRenderDrawBlendMode(sdl_renderer, .BLEND)
	return true
}

render_draw_commands :: proc(
	render_system: ^imgui.Renderer,
	draw_list: ^imgui.Command_List,
) {
	sdl.RenderSetClipRect(sdl_renderer, cast(^sdl.Rect)&draw_list.clips[0])
	sdl.SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255)
	sdl.RenderClear(sdl_renderer)
	src_rect := sdl.Rect {
		0, 0, 1024, 1024
	}
	dst_rect := sdl.Rect {
		0, 0, 1024, 1024
	}
	for command in draw_list.commands {
		switch c in command {
			case imgui.Rect_Command:
				color := c.theme.color
				r, g, b, a: u8
				a = u8(c.color % 256)
				b = u8((c.color >> 8) % 256)
				g = u8((c.color >> 16) % 256)
				r = u8((c.color >> 24) % 256)
				sdl.SetRenderDrawColor(sdl_renderer, r, g, b, a)
				rect := transmute(sdl.Rect)c.rect
				sdl.RenderSetClipRect(sdl_renderer, cast(^sdl.Rect)&draw_list.clips[c.clip_index])
				sdl.RenderFillRect(sdl_renderer, &rect)

			case imgui.Glyph_Command:
				color := c.color
				r, g, b, a: u8
				a = u8(c.color % 256)
				b = u8((c.color >> 8) % 256)
				g = u8((c.color >> 16) % 256)
				r = u8((c.color >> 24) % 256)
				sdl.SetRenderDrawColor(sdl_renderer, r, g, b, a)
				src_rect := sdl.Rect {
					i32(c.uv_rect.pos.x * 1024),
					i32(c.uv_rect.pos.y * 1024),
					i32(c.uv_rect.size.x * 1024),
					i32(c.uv_rect.size.y * 1024),
				}
				dst_rect := sdl.Rect {
					i32(c.rect.pos.x), i32(c.rect.pos.y),
					i32(c.rect.size.x), i32(c.rect.size.y),
				}
				sdl.RenderCopy(sdl_renderer, textures[c.texture_id], &src_rect, &dst_rect)
		}
	}
	sdl.RenderPresent(sdl_renderer)
}

free_renderer :: proc(renderer: ^imgui.Renderer) {
	sdl.DestroyRenderer(sdl_renderer)
}

load_texture :: proc(renderer: ^imgui.Renderer, texture_data: ^imgui.Texture_Data) -> imgui.Texture_Handle {
	pixel_format: sdl.PixelFormatEnum  = .RGBA8888
	rgba_texture_data := make([]u8, texture_data.size.x * texture_data.size.y * 4)
	for y in 0..<texture_data.size.y {
		for x in 0..<texture_data.size.x {
			i := x + y * (texture_data.size.x)
			rgba_texture_data[i * 4 + 0] = texture_data.data[i] > 180 ? 255 : 0
			rgba_texture_data[i * 4 + 1] = 255
			rgba_texture_data[i * 4 + 2] = 255
			rgba_texture_data[i * 4 + 3] = 255
		}
	}
	texture := sdl.CreateTexture(sdl_renderer, u32(pixel_format), .STATIC, i32(texture_data.size.x), i32(texture_data.size.y))
	if texture == nil {
		log.info("Error creating texture")
		log.info(sdl.GetError())
	}
	sdl.UpdateTexture(texture, nil, &rgba_texture_data[0], i32(4 * texture_data.size.x))
	sdl.SetTextureBlendMode(texture, .BLEND)
	next_handle += 1
	textures[next_handle] = texture
	return next_handle
}