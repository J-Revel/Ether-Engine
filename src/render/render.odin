package render

import "core:mem"
import "core:log"
import "core:strings"
import "core:math"
import "core:math/linalg"

import gl "vendor:OpenGL"

@(private="package")
color_fragment_shader_src :: `
#version 450
in vec4 frag_color
in vec2 frag_pos
layout (location = 0) out vec4 out_color

void main()
{
    out_color = 1 - ((1 - frag_color) * (1 - frag_color))
}
`

@(private="package")
color_vertex_shader_src :: `
#version 450
layout (location = 0) in vec2 pos
layout (location = 1) in vec4 color
out vec4 frag_color
out vec2 frag_pos

uniform vec2 screenSize
uniform vec3 camPosZoom

void main()
{
    frag_color = color
    frag_pos = pos
    float zoom = camPosZoom.z
    vec2 camPos = camPosZoom.xy
    vec2 screenPos = (pos.xy - camPos) * 2 / screenSize * camPosZoom.z
    gl_Position = vec4(screenPos.x, -screenPos.y,0,1)
}
`

INDEX_BUFFER_SIZE :: 50000
VERTEX_BUFFER_SIZE :: 20000

extract_rgba :: proc(color: Color) -> (r, g, b, a: u8)
{
	r = u8((color & 0xff000000) / 0x01000000)
	g = u8((color & 0x00ff0000) / 0x00010000)
	b = u8((color & 0x0000ff00) / 0x00000100)
	a = u8(color & 0x000000ff)
	return
}

extract_rgba_int :: proc(color: Color) -> (r, g, b, a: int)
{
	r = int((color & 0xff000000) / 0x01000000)
	g = int((color & 0x00ff0000) / 0x00010000)
	b = int((color & 0x0000ff00) / 0x00000100)
	a = int(color & 0x000000ff)
	return
}

rgba :: proc(r: u8, g: u8, b: u8, a: u8) -> Color
{
	return 0x00000001 * Color(a) + 0x00000100 * Color(b) + 0x00010000 * Color(g) + 0x01000000 * Color(r)
}

rgb :: proc(r: u8, g: u8, b: u8) -> Color
{
	return 0x000000ff + 0x00000100 * Color(b) + 0x00010000 * Color(g) + 0x01000000 * Color(r)
}

hex_char_to_u8 :: proc(c: u8) -> u8
{
	int_value := u8(c - '0')
	lower_char_value := u8(c - 'a')
	upper_char_value := u8(c - 'A')
	if int_value >= 0 && int_value < 10 do return int_value
	if lower_char_value >= 0 && lower_char_value < 6 do return lower_char_value + 10
	if upper_char_value >= 0 && upper_char_value < 6 do return upper_char_value + 10
	return 0
}

rgb_hex :: proc(hex: string) -> Color
{
	parsed_hex := hex
	if len(hex) == 7 && hex[0] == '#' do parsed_hex= hex[1:]
	if len(parsed_hex) == 6
	{
		r, g, b: u8
		r = hex_char_to_u8(parsed_hex[0]) << 4 + hex_char_to_u8(parsed_hex[1])
		g = hex_char_to_u8(parsed_hex[2]) << 4 + hex_char_to_u8(parsed_hex[3])
		b = hex_char_to_u8(parsed_hex[4]) << 4 + hex_char_to_u8(parsed_hex[5])
		return rgb(r, g, b)
	}
	return rgb(0, 0, 0)
}

init_color_renderer :: proc (result: ^Render_State) -> bool
{
    vertexShader := gl.CreateShader(gl.VERTEX_SHADER)
    fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER)
    vertexShaderText := strings.clone_to_cstring(ui_vertex_shader_src, context.temp_allocator)
    fragmentShaderText := strings.clone_to_cstring(color_fragment_shader_src, context.temp_allocator)
    gl.ShaderSource(vertexShader, 1, &vertexShaderText, nil)
    gl.ShaderSource(fragmentShader, 1, &fragmentShaderText, nil)
    gl.CompileShader(vertexShader)
    gl.CompileShader(fragmentShader)
    fragOk: i32
    vertOk: i32
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &vertOk)
    if vertOk == 0 {
        log.errorf("Unable to compile vertex shader: {}", color_vertex_shader_src)
        return false
    }
    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &fragOk)
    if fragOk == 0 || vertOk == 0 {
        log.errorf("Unable to compile fragment shader: {}", color_fragment_shader_src)
        return false
    }

    result.shader = gl.CreateProgram()
    gl.AttachShader(result.shader, vertexShader)
    gl.AttachShader(result.shader, fragmentShader)
    gl.LinkProgram(result.shader)
    ok: i32
    gl.GetProgramiv(result.shader, gl.LINK_STATUS, &ok)
    if ok == 0 {
        log.errorf("Error linking program: {}", result.shader)
        return true
    }

    result.camPosZoomAttrib = gl.GetUniformLocation(result.shader, "camPosZoom")
    result.screenSizeAttrib = gl.GetUniformLocation(result.shader, "screenSize")
    
    gl.GenVertexArrays(1, &result.vao)
    gl.GenBuffers(1, &result.vbo)
    gl.GenBuffers(1, &result.elementBuffer)

    gl.BindVertexArray(result.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, result.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, VERTEX_BUFFER_SIZE * size_of(Color_Vertex_Data), nil, gl.DYNAMIC_DRAW)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, result.elementBuffer)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Color_Vertex_Data), uintptr(0))
    gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Color_Vertex_Data), uintptr(size_of(vec2)))
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    return true
}

push_mesh_data :: proc(render_buffer: ^Sprite_Render_Buffer, vertex: []Sprite_Vertex_Data, index: []u32)
{
    start_index := cast(u32) len(render_buffer.vertex)
    for v in vertex
    {
        append(&render_buffer.vertex, v)
    }

    for i in index
    {
        append(&render_buffer.index, start_index + i)
    }
}

clear_render_buffer :: proc(render_buffer: ^Sprite_Render_Buffer)
{
    clear(&render_buffer.index)
    clear(&render_buffer.vertex)
}

render_buffer_content :: proc(render_system: ^Sprite_Render_System, camera: ^Camera, viewport: Viewport)
{
    vertex_count := len(render_system.buffer.vertex)
    index_count := len(render_system.buffer.index)
    if(vertex_count == 0) do return
    gl.BindVertexArray(render_system.render_state.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, render_system.render_state.vbo)
    
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) vertex_count * size_of(Sprite_Vertex_Data), &render_system.buffer.vertex[0])
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_system.render_state.elementBuffer)
    gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) index_count * size_of(u32), &render_system.buffer.index[0])
    gl.BindVertexArray(0)

    gl.UseProgram(render_system.render_state.shader)
    gl.Uniform3f(render_system.render_state.camPosZoomAttrib, camera.world_pos.x, camera.world_pos.y, camera.zoom)
    gl.Uniform2f(render_system.render_state.screenSizeAttrib, f32(viewport.size.x), f32(viewport.size.y))

    gl.BindVertexArray(render_system.render_state.vao)
    gl.DrawElements(gl.TRIANGLES, cast(i32) index_count, gl.UNSIGNED_INT, nil)
    gl.BindVertexArray(0)
    gl.UseProgram(0)
}

upload_buffer_data :: proc(render_system: ^Sprite_Render_System)
{
    index_count := len(render_system.buffer.index)
    vertex_count := len(render_system.buffer.vertex)
    if(vertex_count == 0) do return

    gl.BindVertexArray(render_system.render_state.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, render_system.render_state.vbo)
    
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) vertex_count * size_of(Sprite_Vertex_Data), &render_system.buffer.vertex[0])
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_system.render_state.elementBuffer)
    gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int)index_count * size_of(u32), &render_system.buffer.index[0])
}

prepare_buffer_render :: proc(render_state: ^Render_State, viewport: Viewport)
{
    gl.BindVertexArray(render_state.vao)
    gl.UseProgram(render_state.shader)
    gl.Uniform2f(render_state.screenSizeAttrib, f32(viewport.size.x), f32(viewport.size.y))
}

cleanup_buffer_render :: proc()
{
    gl.UseProgram(0)
	gl.BindVertexArray(0)
}

use_camera :: proc(render_system: ^Sprite_Render_System, camera: ^Camera)
{
    gl.Uniform3f(render_system.render_state.camPosZoomAttrib, camera.world_pos.x, camera.world_pos.y, camera.zoom)
}

render_buffer_content_part :: proc(render_state: ^Render_State, start_index: int, index_count: int)
{
    gl.DrawElements(gl.TRIANGLES, cast(i32) index_count, gl.UNSIGNED_INT, rawptr(uintptr(size_of(u32) * start_index)))
}

hex_char_val :: proc(r: rune) -> (u32, bool)
{
    if r >= '0' && r <= '9' do return u32(r - '0'), true
    if r >= 'a' && r <= 'f' do return u32(r - 'a' + 10), true
    return 0, false
}

hex_str_val :: proc(str: string) -> (u32, bool)
{
    result: u32
    for c in str
    {
        val, success := hex_char_val(c)
        if !success do return result, false
        result = (result << 4) + val 
    }
    return result, true
}

// hex color : rgb(a)
// u32 color : bgra
hex_color_to_u32 :: proc(hex: string) -> (u32, bool)
{
    result : u32 = 0
    if len(hex) != 6 && len(hex) != 8 do return 0, false
    r, r_success := hex_str_val(hex[0:2])
    g, g_success := hex_str_val(hex[2:4])
    b, b_success := hex_str_val(hex[4:6])
    result += r + g * (1 << 8) + b * (1 << 16)
    if len(hex) == 8
    {
        a, a_success := hex_str_val(hex[6:8])
        result += a * (1 << 24)
    }
    else
    {
        result += 255 << 24
    }
    return result, true
}

color_replace_alpha :: proc(color: u32, alpha: int) -> u32
{
    return (color & 0x00ffffff) | u32(alpha << 24)
}

screen_to_world :: proc(camera: ^Camera, viewport: Viewport, screen_pos: [2]int) -> (world_pos: [2]f32)
{
    viewport_center := viewport.top_left + viewport.size / 2
    return camera.world_pos + linalg.to_f32(screen_pos - viewport_center) * camera.zoom * [2]f32{1, -1}
}

world_to_screen :: proc(camera: ^Camera, viewport: Viewport, world_pos: [2]f32) -> (screen_pos: [2]int)
{
    viewport_center := viewport.top_left + viewport.size / 2
    return viewport_center + linalg.to_int((world_pos - camera.world_pos) / camera.zoom) * [2]int{1, -1}
}
