package render
import sdl_image "shared:odin-sdl2/image"
import sdl "shared:odin-sdl2"
import "core:strings"
import "core:log"
import gl "shared:odin-gl";
import "core:os"
import "core:encoding/json"
import "core:sort"
import "core:fmt"
import "core:runtime"
import "core:math"

import "../container"
import "../../libs/imgui"
import "../objects"
import "../util"

@(private="package")
sprite_fragment_shader_src :: `
#version 450
in vec4 frag_color;
in vec2 frag_pos;
in vec2 frag_uv;
layout (location = 0) out vec4 out_color;
uniform sampler2D tex;

void main()
{
    out_color = frag_color * texture(tex, frag_uv);
}
`;

@(private="package")
sprite_vertex_shader_src :: `
#version 450
layout (location = 0) in vec2 pos;
layout(location = 1) in vec2 uv;
layout (location = 2) in vec4 color;
out vec4 frag_color;
out vec2 frag_pos;
out vec2 frag_uv;

uniform vec2 screenSize;
uniform vec3 camPosZoom;


void main()
{
    frag_color = color;
    frag_pos = pos;
    frag_uv = uv;
    float zoom = camPosZoom.z;
    vec2 camPos = camPosZoom.xy;
    vec2 screenPos = (pos.xy - camPos) * 2 / screenSize * camPosZoom.z;
    gl_Position = vec4(screenPos.x, -screenPos.y,0,1);
}
`;

@(private="package")
ui_vertex_shader_src :: `
#version 450
layout (location = 0) in vec2 pos;
layout(location = 1) in vec2 uv;
layout (location = 2) in vec4 color;
layout (location = 3) in vec4 clip;
out vec4 frag_color;
out vec2 frag_pos;
out vec2 frag_uv;

uniform vec2 screenSize;

void main()
{
    frag_color = color;
    frag_pos = pos;
    frag_uv = uv;
    vec2 screenPos = pos.xy * 2 / screenSize - vec2(1, 1);
	screenPos.x = min(screenPos.x, 0.3);
	screenPos.y = min(screenPos.y, 0.5);
    gl_Position = vec4(screenPos.x, -screenPos.y,0,1);
}
`;

@(private="package")
text_vertex_shader_src :: `
#version 450
struct Rect
{
	vec4 pos_size;
	vec4 color;
}
`;

load_texture :: proc(path: string) -> (Texture, bool)
{
	cstring_path := strings.clone_to_cstring(path, context.temp_allocator);
	surface := sdl_image.load(cstring_path);
    if surface == nil
    {
        return {}, false;
    }
	defer sdl.free_surface(surface);
	texture_id: u32;
	gl.GenTextures(1, &texture_id);
	gl.BindTexture(gl.TEXTURE_2D, texture_id);

	mode := gl.RGB;
 	
	if surface.format.bytes_per_pixel == 4 do mode = gl.RGBA;
	 
	gl.TexImage2D(gl.TEXTURE_2D, 0, i32(mode), surface.w, surface.h, 0, u32(mode), gl.UNSIGNED_BYTE, surface.pixels);
	 
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

	bindless_id := GetTextureHandleARB(texture_id);
	MakeTextureHandleResidentARB(bindless_id);
	result_texture := Texture{
		path = strings.clone(path),
		texture_id = texture_id,
		bindless_id = bindless_id,
		resident = true,
		size = {int(surface.w), int(surface.h)}
	};
	return result_texture, true;
}

unload_texture :: proc(texture: ^Texture)
{
    gl.DeleteTextures(1, &texture.texture_id);
}

get_or_load_texture :: proc(using db: ^Sprite_Database, texture_path: string) -> (Texture_Handle, bool)
{
    texture_it := container.table_iterator(&textures);
    loaded_texture_handle: Texture_Handle;
    for texture_data, texture_handle in container.table_iterate(&texture_it)
    {
        if texture_data.path == texture_path
        {
            return texture_handle, true;
        }
    }
    loaded_texture_data, texture_load_ok := load_texture(texture_path);
    if texture_load_ok
    {
        texture_handle, ok := container.table_add(&textures, loaded_texture_data);
        assert(ok);
        return texture_handle, true;
    }
    else
    {
        return {}, false;
    }
}

get_sprite :: proc(using db: ^Sprite_Database, texture_handle: Texture_Handle, sprite_id: string) -> (Sprite_Handle, bool)
{
    sprite_it := container.table_iterator(&sprites);
    for sprite, sprite_handle in container.table_iterate(&sprite_it)
    {
        if sprite.id == sprite_id && sprite.texture == texture_handle
        {
            return sprite_handle, true;
        }
    }
    return {}, false;
}

get_sprite_any_texture :: proc(using db: ^Sprite_Database, sprite_id: string) -> (Sprite_Handle, bool)
{
    sprite_it := container.table_iterator(&sprites);
    for sprite, sprite_handle in container.table_iterate(&sprite_it)
    {
        if sprite.id == sprite_id
        {
            return sprite_handle, true;
        }
    }
    return {}, false;

}

get_or_load_sprite :: proc(using db: ^Sprite_Database, asset: Sprite_Asset) -> (Sprite_Handle, bool)
{
    texture_handle, texture_loaded := get_or_load_texture(db, fmt.tprintf("%s.png", asset.path));

    result, sprite_found := get_sprite(db, texture_handle, asset.sprite_id);

    if sprite_found do return result, true;

    sprites_path := fmt.tprintf("%s.meta", asset.path);
    loaded_sprites_names, loaded_sprites_data, load_ok := load_sprites_data(sprites_path, context.temp_allocator);
    if load_ok
    {
        result_found := false;
        for loaded_sprite_name, index in loaded_sprites_names
        {
            loaded_sprite_data := loaded_sprites_data[index];
            new_sprite := Sprite{texture_handle, strings.clone(loaded_sprite_name, context.allocator), loaded_sprite_data};
            // TODO : maybe should check for existence in the table before adding it ?
            new_sprite_handle, add_ok := container.table_add(&sprites, new_sprite);
            assert(add_ok);

            if loaded_sprite_name == asset.sprite_id
            {
                result = new_sprite_handle;
                result_found = true;
            }

        }
        return result, result_found;
    }
    return {}, false;
}

load_sprites_to_db :: proc(using db: ^Sprite_Database, texture_handle: Texture_Handle, sprites_path: string) -> bool
{
    loaded_sprites_names, loaded_sprites_data, load_ok := load_sprites_data(sprites_path);
    if load_ok
    {
        for loaded_sprite_name, index in loaded_sprites_names
        {
            loaded_sprite_data := loaded_sprites_data[index];

            new_sprite := Sprite{texture_handle, strings.clone(loaded_sprite_name), loaded_sprite_data};
            _, sprite_present := get_sprite(db, texture_handle, loaded_sprite_name);
            if !sprite_present
            {
                new_sprite_handle, add_ok := container.table_add(&sprites, new_sprite);
                assert(add_ok);
            }
        }
    }
    return load_ok;
}

// Sprites are all stored in a file by 
//load_sprites_from_file :: proc(path: string, ) -> 

sprite_sort_interface := sort.Interface {
    len = proc(it: sort.Interface) -> int 
    {
        sprites := cast(^[]Sprite)it.collection;
        return len(sprites);
    },
    less = proc(it: sort.Interface, i, j: int) -> bool
    {
        s := (^[]Sprite)(it.collection);
        return s[i].texture.id < s[j].texture.id;
    },
    swap = proc(it: sort.Interface, i, j: int)
    {
        s := (^[]Sprite)(it.collection);
        s[i], s[j] = s[j], s[i];
    }
};

save_sprites_to_file :: proc(path: string, sprites_ids: []Sprite_Handle) -> os.Errno
{
    file_handle, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC);
    if err != os.ERROR_NONE
    {
        return err;
    }

    sprite_count: map[string] struct{count: int, cursor: int};
    max_sprite_per_texture := 0;
    texture_count := 0;

    sorted_sprites := make([]Sprite, len(sprites_ids), context.temp_allocator);


    for sprite_id, index in sprites_ids
    {
        sprite := container.handle_get(sprite_id);
        sorted_sprites[index] = sprite^;
    }

    sprite_sort_interface.collection = &sorted_sprites;
    sort.sort(sprite_sort_interface);
    
    current_texture: Texture_Handle;
    write_buf := make([]byte, 500, context.temp_allocator);
    fmt.bprint(write_buf, "{");
    os.write(file_handle, write_buf[0:1]);
    for sprite in sorted_sprites
    {
        if sprite.texture.id != current_texture.id
        {
            fmt.bprint(write_buf, "],");
            if current_texture.id > 0 do os.write(file_handle, write_buf[0:3]);
            texture := container.handle_get(sprite.texture);
            str := fmt.bprintf(write_buf, "\"%s\": [", texture.path);
            
            os.write(file_handle, write_buf[0:len(str)]);
            current_texture = sprite.texture;
        }
        else
        {
            fmt.bprint(write_buf, ",");
            os.write(file_handle, write_buf[0:1]);
        }
        encoded, marshal_error := json.marshal(sprite.data);
        if marshal_error == .None do os.write_string(file_handle, strings.string_from_ptr(&encoded[0], len(encoded)));
        else do log.error(marshal_error);
    }
    fmt.bprint(write_buf, "]}");
    os.write(file_handle, write_buf[0:2]);
    os.close(file_handle);
    return 0;
}

save_sprites_to_file_editor :: proc(path: string, sprite_names: []string, sprites_data: []Sprite_Data) -> os.Errno
{
    file_handle, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC);
    if err != os.ERROR_NONE
    {
        return err;
    }
    
    current_texture: Texture_Handle;
    write_buf := make([]byte, 500, context.temp_allocator);
    fmt.bprint(write_buf, "{");
    os.write(file_handle, write_buf[0:1]);
    for sprite_data, index in sprites_data
    {
        if(index > 0)
        {
            fmt.bprint(write_buf, ",");
            os.write(file_handle, write_buf[0:1]);
        }

        encoded, marshal_error := json.marshal(sprite_data, context.temp_allocator);
        if marshal_error == .None
        {
            str := fmt.tprintf("\"%s\": %s", sprite_names[index], encoded);
            os.write_string(file_handle, str);
        }
        else
        {
            log.error(marshal_error);
        }
        //os.write(file_handle, );
    }   
    os.write_string(file_handle, "}");
    os.close(file_handle);
    return 0;
}

// DEPRECATED : does not load the same version of sprite files as the editor version. Use load_sprites_data instead
load_sprites_from_file :: proc (path: string, textures: ^container.Table(Texture), sprites: ^container.Table(Sprite)) -> bool
{
    file, ok := os.read_entire_file(path, context.temp_allocator);
    if ok
    {
        parsed, ok := json.parse(file);
        parsed_object := parsed.value.(json.Object);

        for texture_path, sprite_list in parsed_object
        {
            texture, ok := load_texture(texture_path);
            assert(ok);
            texture_id, texture_add_ok := container.table_add(textures, texture);
            sprite := Sprite{texture = texture_id};
            for sprite_data in sprite_list.value.(json.Array)
            {
                sprite_data_root := sprite_data.value.(json.Object);
                anchor_data := sprite_data_root["anchor"].value.(json.Array);
                clip_data := sprite_data_root["clip"].value.(json.Object);
                clip_pos_data := clip_data["pos"].value.(json.Array);
                clip_size_data := clip_data["size"].value.(json.Array);

                sprite.id = strings.clone(sprite_data_root["id"].value.(json.String));
                sprite.anchor.x = f32(anchor_data[0].value.(json.Float));
                sprite.anchor.y = f32(anchor_data[1].value.(json.Float));
                sprite.clip.pos.x = f32(clip_pos_data[0].value.(json.Float));
                sprite.clip.pos.y = f32(clip_pos_data[1].value.(json.Float));
                sprite.clip.size.x = f32(clip_size_data[0].value.(json.Float));
                sprite.clip.size.y = f32(clip_size_data[1].value.(json.Float));
                container.table_add(sprites, sprite);
            }
        }

        return true;
    }

    return false;
}

load_sprites_data :: proc (path: string, allocator := context.temp_allocator) -> ([]string, []Sprite_Data, bool)
{
    file, ok := os.read_entire_file(path, context.temp_allocator);
    if ok
    {
        parsed, ok := json.parse(file, .JSON, false, context.temp_allocator);
        parsed_object := parsed.value.(json.Object);

        sprite := Sprite_Data{};

        sprite_count := len(parsed_object);
        out_data := make([]Sprite_Data, sprite_count, allocator);
        out_names := make([]string, sprite_count, allocator);
        cursor := 0;

        for sprite_name, sprite_data in parsed_object
        {
            sprite_data_root := sprite_data.value.(json.Object);
            anchor_data := sprite_data_root["anchor"].value.(json.Array);
            clip_data := sprite_data_root["clip"].value.(json.Object);
            clip_pos_data := clip_data["pos"].value.(json.Array);
            clip_size_data := clip_data["size"].value.(json.Array);

            sprite.anchor.x = f32(anchor_data[0].value.(json.Float));
            sprite.anchor.y = f32(anchor_data[1].value.(json.Float));
            sprite.clip.pos.x = f32(clip_pos_data[0].value.(json.Float));
            sprite.clip.pos.y = f32(clip_pos_data[1].value.(json.Float));
            sprite.clip.size.x = f32(clip_size_data[0].value.(json.Float));
            sprite.clip.size.y = f32(clip_size_data[1].value.(json.Float));

            out_names[cursor] = sprite_name;
            out_data[cursor] = sprite;
            cursor += 1;
        }
        return out_names, out_data, true;
    }
    return {}, {}, false;
}

generate_default_white_texture :: proc() -> (texture_id: u32) 
{
    gl.GenTextures(1, &texture_id);

    data: []u8 = { 255, 255, 255, 255 };

    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, &data[0]);
    gl.BindTexture(gl.TEXTURE_2D, 0);
    return texture_id;
}

init_sprite_renderer :: proc (result: ^Render_State, render_type: Sprite_Render_Type) -> bool
{
    vertex_shader := gl.CreateShader(gl.VERTEX_SHADER);
    fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER);
	vertex_shader_src: string;
	switch render_type
	{
		case .World:
			vertex_shader_src = sprite_vertex_shader_src;
		case .UI:
			vertex_shader_src = ui_vertex_shader_src;
	}

    vertex_shader_cstring := cast(^u8)strings.clone_to_cstring(vertex_shader_src, context.temp_allocator);
    fragment_shader_cstring := cast(^u8)strings.clone_to_cstring(sprite_fragment_shader_src, context.temp_allocator);
    gl.ShaderSource(vertex_shader, 1, &vertex_shader_cstring, nil);
    gl.ShaderSource(fragment_shader, 1, &fragment_shader_cstring, nil);
    gl.CompileShader(vertex_shader);
    gl.CompileShader(fragment_shader);
    frag_ok: i32;
    vert_ok: i32;
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vert_ok);
    if vert_ok != gl.TRUE {
    	error_length: i32;
    	gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &error_length);
    	error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
    	gl.GetShaderInfoLog(vertex_shader, error_length, nil, &error[0]);
        log.errorf("Unable to compile vertex shader: {}", cstring(&error[0]));
        return false;
    }
    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &frag_ok);
    if frag_ok != gl.TRUE {
    	error_length: i32;
    	gl.GetShaderiv(fragment_shader, gl.INFO_LOG_LENGTH, &error_length);
    	error: []u8 = make([]u8, error_length + 1, context.temp_allocator);
    	gl.GetShaderInfoLog(fragment_shader, error_length, nil, &error[0]);
        log.errorf("Unable to compile fragment shader: {}", cstring(&error[0]));
        return false;
    }

    result.shader = gl.CreateProgram();
    gl.AttachShader(result.shader, vertex_shader);
    gl.AttachShader(result.shader, fragment_shader);
    gl.LinkProgram(result.shader);
    ok: i32;
    gl.GetProgramiv(result.shader, gl.LINK_STATUS, &ok);
    if ok != gl.TRUE {
        log.errorf("Error linking program: {}", result.shader);
        return true;
    }

    result.camPosZoomAttrib = gl.GetUniformLocation(result.shader, "camPosZoom");
    result.screenSizeAttrib = gl.GetUniformLocation(result.shader, "screenSize");
    
    gl.GenVertexArrays(1, &result.vao);
    gl.GenBuffers(1, &result.vbo);
    gl.GenBuffers(1, &result.elementBuffer);

    gl.BindVertexArray(result.vao);
    gl.BindBuffer(gl.ARRAY_BUFFER, result.vbo);
    gl.BufferData(gl.ARRAY_BUFFER, VERTEX_BUFFER_SIZE * size_of(Sprite_Vertex_Data), nil, gl.DYNAMIC_DRAW);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, result.elementBuffer);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, INDEX_BUFFER_SIZE * size_of(u32), nil, gl.DYNAMIC_DRAW);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), nil);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), rawptr(uintptr(size_of(vec2))));
    gl.VertexAttribPointer(2, 4, gl.FLOAT, 0, size_of(Sprite_Vertex_Data), rawptr(uintptr(size_of(vec2) * 2)));
    gl.EnableVertexAttribArray(0);
    gl.EnableVertexAttribArray(1);
    gl.EnableVertexAttribArray(2);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    result.default_texture = generate_default_white_texture();

    return true;
}

render_sprite :: proc(
    render_system: ^Sprite_Render_System, 
    using sprite: ^Sprite, 
    using absolute_transform: objects.Transform, 
    color: Color)
{
    imgui.text_unformatted(fmt.tprint("render_sprite", sprite.texture));
    start_index := cast(u32) len(render_system.buffer.vertex);
    texture_data := container.handle_get(texture);
    texture_size_i := texture_data.size;
    if texture != render_system.current_texture
    {
        index_count := len(render_system.buffer.index);
        if index_count > 0
        {
            imgui.text_unformatted(fmt.tprint(index_count));
            
            pass_texture: Texture_Handle = {};
            if container.is_valid(render_system.current_texture)
            {
                pass_texture = render_system.current_texture;
            }
            append(&render_system.passes, Sprite_Render_Pass {
                    pass_texture, 
                    index_count - render_system.current_pass_index
            });
            render_system.current_pass_index = index_count;
            imgui.text_unformatted(fmt.tprint("set pass_index", render_system.current_pass_index));

        }

        render_system.current_texture = texture;
    }

    texture_size: [2]f32 = {f32(texture_size_i.x), f32(texture_size_i.y)};
    clip_size := [2]f32{
    	clip.size.x > 0 ? clip.size.x : 1,
    	clip.size.y > 0 ? clip.size.y : 1
    };
    render_size := texture_size * clip_size;

    vertex_data : Sprite_Vertex_Data;
    right := [2]f32{math.cos(angle), math.sin(angle)} * render_size.x;
    up := [2]f32{math.cos(angle + math.PI / 2), math.sin(angle + math.PI / 2)} * render_size.y;

    left_pos := pos.x - render_size.x * anchor.x * scale;
    right_pos := pos.x + render_size.x * (1 - anchor.x) * scale;
    top_pos := pos.y - render_size.y * anchor.y * scale;
    bottom_pos := pos.y + render_size.y * (1 - anchor.y) * scale;

    left_uv := clip.pos.x;
    right_uv := clip.pos.x + clip_size.x;
    top_uv := clip.pos.y;
    bottom_uv := clip.pos.y + clip_size.y;

    vertex_data.pos = pos - right * anchor.x * scale - up * (1-anchor.y) * scale;
    vertex_data.color = color;
    vertex_data.uv = clip.pos + {0, clip_size.y};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = pos + right * (1 - anchor.x) * scale - up * (1-anchor.y) * scale;
    vertex_data.uv = clip.pos + {clip_size.x, clip_size.y};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = pos - right * anchor.x * scale + up * anchor.y * scale;
    vertex_data.uv = clip.pos + {0, 0};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = pos + right * (1 - anchor.x) * scale + up * anchor.y * scale; 
    vertex_data.uv = clip.pos + {clip_size.x, 0};
    append(&render_system.buffer.vertex, vertex_data);

    append(&render_system.buffer.index, start_index);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 3);
}

use_texture :: proc(
    render_system: ^Sprite_Render_System, 
	texture: Texture_Handle)
{
    if texture != render_system.current_texture
    {
        index_count := len(render_system.buffer.index);
        if index_count > 0
        {
            pass_texture: Texture_Handle = {};
            if container.is_valid(render_system.current_texture)
            {
                pass_texture = render_system.current_texture;
            }
            append(&render_system.passes, Sprite_Render_Pass {
                    pass_texture, 
                    index_count - render_system.current_pass_index
            });
            render_system.current_pass_index = index_count;
        }

        render_system.current_texture = texture;
    }
}

render_quad :: proc(render_system: ^Sprite_Render_System, pos: [2]f32, size: [2]f32, color: Color)
{
    imgui.text_unformatted(fmt.tprint("render_quad"));
    start_index := cast(u32) len(render_system.buffer.vertex);
    
    if container.is_valid(render_system.current_texture)
    {
        index_count := len(render_system.buffer.index);
        append(&render_system.passes, Sprite_Render_Pass {
                render_system.current_texture, 
                index_count - render_system.current_pass_index
        });
        render_system.current_pass_index = index_count;
        imgui.text_unformatted(fmt.tprint("set pass_index", render_system.current_pass_index));
        render_system.current_texture = {};
    }

    vertex_data : Sprite_Vertex_Data;
    left_pos := pos.x;
    right_pos := pos.x + size.x;
    top_pos := pos.y;
    bottom_pos := pos.y - size.y;

    vertex_data.pos = [2]f32{left_pos, top_pos};
    vertex_data.color = color;
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{right_pos, top_pos};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{left_pos, bottom_pos};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{right_pos, bottom_pos};

    append(&render_system.buffer.vertex, vertex_data);

    append(&render_system.buffer.index, start_index);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 3);
}

render_rotated_quad :: proc(
	render_system: ^Sprite_Render_System,
	pos: [2]f32,
	size: [2]f32,
	angle: f32,
	pivot: [2]f32,
	color: Color,
)
{
    imgui.text_unformatted(fmt.tprint("render_rotated_quad", render_system.current_texture.id, render_system.current_pass_index));
    start_index := cast(u32) len(render_system.buffer.vertex);
    
    imgui.text_unformatted(fmt.tprint("current_pass_index", render_system.current_pass_index));
    if container.is_valid(render_system.current_texture)
    {
        index_count := len(render_system.buffer.index);
        imgui.text_unformatted(fmt.tprint("index_count", index_count));
        append(&render_system.passes, Sprite_Render_Pass {
            texture = render_system.current_texture, 
            index_count = index_count - render_system.current_pass_index
        });
        render_system.current_pass_index = index_count;
        imgui.text_unformatted(fmt.tprint("set pass_index", render_system.current_pass_index));
        render_system.current_texture = {};

        imgui.text_unformatted(fmt.tprint("append pass"));
    }

    vertex_data : Sprite_Vertex_Data;
    bottom_left_point := pos - size * pivot;
    right := [2]f32{math.cos(angle), math.sin(angle)};
    up := [2]f32{math.cos(angle + math.PI / 2), math.sin(angle + math.PI / 2)};

    vertex_data.pos = bottom_left_point;
    vertex_data.color = color;
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = bottom_left_point + right * size.x;
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = bottom_left_point + right * size.x + up * size.y;
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = bottom_left_point + up * size.y;

    append(&render_system.buffer.vertex, vertex_data);

    append(&render_system.buffer.index, start_index);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 0);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 3);
}

push_quad_vertices :: proc(render_system: ^Sprite_Render_System, using rect: util.Rect, color: Color)
{
    start_index := cast(u32) len(render_system.buffer.vertex);
    vertex_data : Sprite_Vertex_Data;
    left_pos := pos.x;
    right_pos := pos.x + size.x;
    top_pos := pos.y;
    bottom_pos := pos.y - size.y;

    vertex_data.pos = [2]f32{left_pos, top_pos};
    vertex_data.color = color;
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{right_pos, top_pos};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{left_pos, bottom_pos};
    append(&render_system.buffer.vertex, vertex_data);

    vertex_data.pos = [2]f32{right_pos, bottom_pos};

    append(&render_system.buffer.vertex, vertex_data);

    append(&render_system.buffer.index, start_index);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 1);
    append(&render_system.buffer.index, start_index + 2);
    append(&render_system.buffer.index, start_index + 3);
}

render_rounded_quad :: proc(render_system: ^Sprite_Render_System, using rect: util.Rect, corner_radius: f32, color: Color, corner_subdivisions: int = 3)
{
    imgui.text_unformatted(fmt.tprint("render_quad"));
    
    if container.is_valid(render_system.current_texture)
    {
        index_count := len(render_system.buffer.index);
        append(&render_system.passes, Sprite_Render_Pass {
                render_system.current_texture, 
                index_count - render_system.current_pass_index
        });
        render_system.current_pass_index = index_count;
        imgui.text_unformatted(fmt.tprint("set pass_index", render_system.current_pass_index));
        render_system.current_texture = {};
    }
	push_quad_vertices(render_system, util.Rect{pos + [2]f32{0, corner_radius}, [2]f32{corner_radius, size.y - 2 * corner_radius}}, color);
	push_quad_vertices(render_system, util.Rect{pos + [2]f32{size.x - corner_radius, corner_radius}, [2]f32{corner_radius, size.y - 2 * corner_radius}}, color);
	push_quad_vertices(render_system, util.Rect{pos + [2]f32{corner_radius, 0}, [2]f32{size.x - 2 * corner_radius, size.y}}, color);
}

render_sprite_buffer_content :: proc(render_system: ^Sprite_Render_System, camera: ^Camera, viewport: Viewport)
{
    upload_buffer_data(render_system);
    index_cursor := 0;

    texture_id: u32 = render_system.render_state.default_texture;
    for pass, index in render_system.passes
    {
		if container.is_valid(pass.texture) do texture_id = container.handle_get(pass.texture).texture_id;
		gl.BindTexture(gl.TEXTURE_2D, texture_id);
		prepare_buffer_render(&render_system.render_state, viewport);
		use_camera(render_system, camera);
		render_buffer_content_part(&render_system.render_state, index_cursor, pass.index_count);
		cleanup_buffer_render();
		index_cursor += pass.index_count;
    }
    texture_id = render_system.render_state.default_texture;
    if container.is_valid(render_system.current_texture) do texture_id = container.handle_get(render_system.current_texture).texture_id;
    gl.BindTexture(gl.TEXTURE_2D, texture_id);
	prepare_buffer_render(&render_system.render_state, viewport);
	use_camera(render_system, camera);
	render_buffer_content_part(
		&render_system.render_state, 
		index_cursor, 
		len(render_system.buffer.index) - index_cursor
	);
	cleanup_buffer_render();
    imgui.text_unformatted(fmt.tprint("last pass", render_system.current_texture.id, len(render_system.buffer.index) - index_cursor));

}

render_ui_buffer_content :: proc(render_system: ^Sprite_Render_System, viewport: Viewport)
{
    upload_buffer_data(render_system);
    index_cursor := 0;

    for pass, index in render_system.passes
    {
		texture_id := container.is_valid(pass.texture) ? 
						container.handle_get(pass.texture).texture_id : render_system.render_state.default_texture;
        gl.BindTexture(gl.TEXTURE_2D, texture_id);
		prepare_buffer_render(&render_system.render_state, viewport);
        render_buffer_content_part(&render_system.render_state, index_cursor, pass.index_count);
		cleanup_buffer_render();
        index_cursor += pass.index_count;
    }
	texture_id := container.is_valid(render_system.current_texture) ? 
					container.handle_get(render_system.current_texture).texture_id : render_system.render_state.default_texture;
    gl.BindTexture(gl.TEXTURE_2D, texture_id);
	prepare_buffer_render(&render_system.render_state, viewport);
	render_buffer_content_part(
		&render_system.render_state, 
		index_cursor, 
		len(render_system.buffer.index) - index_cursor
	);
	cleanup_buffer_render();
    imgui.text_unformatted(fmt.tprint("last pass", render_system.current_texture.id, len(render_system.buffer.index) - index_cursor));

}

clear_sprite_render_buffer :: proc(render_system: ^Sprite_Render_System)
{
    clear(&render_system.buffer.index);
    clear(&render_system.buffer.vertex);
    clear(&render_system.passes);
    render_system.current_texture = {};
    render_system.current_pass_index = 0;
}

init_sprite_database :: proc(using db: ^Sprite_Database, texture_cap : uint = 100, sprite_cap : uint = 200)
{
    container.table_init(&textures, texture_cap);
    container.table_init(&sprites, sprite_cap);
}
