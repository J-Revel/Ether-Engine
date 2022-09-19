package imgui_wasm

import imgui ".."
import "core:math/linalg"
import "core:math"

next_handle: imgui.Texture_Handle

init_renderer :: proc(window: ^sdl.Window, renderer: ^imgui.Renderer) -> bool {

	return true
}

render_draw_commands :: proc(
	render_system: ^imgui.Renderer,
	draw_list: ^imgui.Command_List,
) {

}

free_renderer :: proc(renderer: ^imgui.Renderer) {

}

load_texture :: proc(renderer: ^imgui.Renderer, texture_data: ^imgui.Texture_Data) -> imgui.Texture_Handle {
	pixel_format: sdl.PixelFormatEnum  = .RGB888
	rgba_texture_data := make([]u8, texture_data.size.x * texture_data.size.y * 3)
	for y in 0..<texture_data.size.y {
		for x in 0..<texture_data.size.x {
			i := x + y * (texture_data.size.x)
			rgba_texture_data[i * 3 + 0] = 0
			rgba_texture_data[i * 3 + 1] = u8(y * 255 / texture_data.size.y)
			rgba_texture_data[i * 3 + 2] = u8(x * 255 / texture_data.size.x)
		}
	}
	if texture == nil {
	}
	next_handle += 1
	textures[next_handle] = texture
	return next_handle
}