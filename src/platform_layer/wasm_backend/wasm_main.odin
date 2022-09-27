package windows_sdl_backend

import "core:mem"
import "core:strings"
import "core:runtime"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:fmt"
import "core:time"
import "core:encoding/json"
import "vendor:wasm/js"

import "../../input"
import "../../imgui"
import platform_layer "../base"
import "core:intrinsics"


DESIRED_GL_MAJOR_VERSION :: 4
DESIRED_GL_MINOR_VERSION :: 5
FRAME_SAMPLE_COUNT :: 10

default_screen_size :: [2]i32{1280, 720}


running := true

vec2 :: [2]f32
ivec2 :: [2]i32

PAGE_SIZE :: 64 * 1024
page_alloc :: proc(page_count: int) -> (data: []byte, err: mem.Allocator_Error) {
    prev_page_count := intrinsics.wasm_memory_grow(0, uintptr(page_count))
    if prev_page_count < 0 {
        return nil, .Out_Of_Memory
    }

    ptr := ([^]u8)(uintptr(prev_page_count) * PAGE_SIZE)
    return ptr[:page_count * PAGE_SIZE], nil
}

page_allocator :: proc() -> mem.Allocator {
    procedure :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
                      size, alignment: int,
                      old_memory: rawptr, old_size: int,
                      location := #caller_location) -> ([]byte, mem.Allocator_Error) {
        switch mode {
        case .Alloc:
            assert(size % PAGE_SIZE == 0)
            return page_alloc(size/PAGE_SIZE)
        case .Resize, .Free, .Free_All, .Query_Info:
            return nil, .Mode_Not_Implemented
        case .Query_Features:
            set := (^mem.Allocator_Mode_Set)(old_memory)
            if set != nil {
                set^ = {.Alloc, .Query_Features}
            }
        }

        return nil, nil
    }

    return {
        procedure = procedure,
        data = nil,
    }
}


print_int :: proc(x: int) {
    test := [10]string {"0", "1", "2", "3", "4","5","6","7","8","9"}
    for y:=x; y>0; y/=10 {
        js.log(test[y%10])
    }
}

main :: proc() {
    context.allocator = page_allocator()
    prev_page_count := intrinsics.wasm_memory_grow(0, 4096)
    print_int(intrinsics.wasm_memory_size(0))
    
}
    
test :: proc() {    
    // log.info("Starting SDL Example...")
    window, err := init(default_screen_size)

    // load_opengl(window)
    
	// render.load_ARB_bindless_texture(load_proc)
	test_frequency : f32 = 440
	
	// audio_system: audio.Audio_System
	// audio.init_audio_system(&audio_system)
    // gl.ClearColor(0, 0.25, 0.25, 1)

    // imgui_state := init_imgui_state(window)
    input_state : input.State

    // show_demo_window := false
    // io := imgui.get_io()

    imgui_state: imgui.UI_State = {
        input_state = &input_state,
    }
    viewport := imgui.I_Rect{
        {0, 0},
        default_screen_size,
    }
    // imgui_state.render_system = {
    //     render_draw_commands = imgui_wasm.render_draw_commands,
    //     load_texture = imgui_wasm.load_texture,
    //     free_renderer = imgui_wasm.free_renderer,
    // }
    // imgui_wasm.init_renderer(window, &imgui_state.render_system)
    imgui.init_ui_state(&imgui_state, viewport)
    button_theme: imgui.Button_Theme = { 
        {
            color = 0x00ffffff,
            corner_radius = 3,
        }, 
        {
            color = 0xffffffff,
            corner_radius = 3,
        }, 
        {
            color = 0xff0000ff,
            corner_radius = 3,
        }
    }
    slider_theme: imgui.Slider_Theme = { 
        {
            color = 0x555555ff,
        },
        button_theme,
        10,
    }
    window_background_theme: platform_layer.Rect_Theme = {
        color = 0x333333ff,
    }
    scrollzone_theme: imgui.Scrollzone_Theme = {
        slider_theme,
        window_background_theme,
        10,
    }
    header_theme: imgui.Button_Theme = {
        {
            color = 0x003333ff,
            corner_radius = 3,
        }, 
        {
            color = 0x004444ff,
            corner_radius = 3,
        }, 
        {
            color = 0x005555ff,
            corner_radius = 3,
        }
    }
    title_text_theme: platform_layer.Text_Theme = {
        font = platform_layer.load_font("resources/fonts/Roboto-Regular.ttf"),
        size = 20,
        color = 0xffffffff,
    }
    window_theme: imgui.Window_Theme = {
        scrollzone_theme,
        30,
        header_theme,
        title_text_theme,
    }

    text_field_caret_theme : platform_layer.Rect_Theme = {
        color = 0xffffffff,
        corner_radius = 3,
    }

    text_block_theme : imgui.Text_Block_Theme = {
        title_text_theme,
        {0.5, 0.5},
    }

    text_field_theme: imgui.Text_Field_Theme = {
        button_theme,
        text_block_theme,
        text_field_caret_theme,
        2
    }

    editor_theme: imgui.Editor_Theme = {
        button_theme,
        text_field_theme,
        window_theme,
    }
    data, _ := json.marshal(editor_theme, {pretty = true})
    // log.info(string(data))
    
    last_frame_tick := time.tick_now()
    sample_frame_times: [FRAME_SAMPLE_COUNT]f32
    frame_index := 0

    font_scale : f32 = 1
    test_scroll_value : i32 = 0
    test_window_rect := imgui.I_Rect {
        pos = {200, 100},
        size = {500, 300},
    }

    caret_position : i32 = 0
    text_input_value := "This is a test"

    for running {
		// handle_opengl_error()

        // sdl.GL_GetDrawableSize(window, &mx, &my)
        
        input.new_frame(&input_state)
        platform_layer.update_events(window, &input_state)
        // input.process_events(&input_state)
        // input.update_mouse(&input_state, window)
        // input.update_display_size(window)

        // imgui.new_frame()
        // {
        //     info_overlay()
        // }

     //    gl.Viewport(0, 0, mx, my)
     //    gl.Scissor(0, 0, mx, my)
     //    gl.Clear(gl.COLOR_BUFFER_BIT)
     //    gl.Enable(gl.BLEND);
        // gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        current_tick := time.tick_now()
        delta_time := f32(time.duration_seconds(time.tick_diff(last_frame_tick, current_tick)))
        sample_frame_times[frame_index % FRAME_SAMPLE_COUNT] = delta_time
        sample_time_sum: f32 = 0
        for i in 0..<FRAME_SAMPLE_COUNT do sample_time_sum += sample_frame_times[i]
        frame_index += 1
        last_frame_tick = current_tick
        
        viewport = imgui.I_Rect{
            {0, 0},
            linalg.to_i32(platform_layer.get_window_size(window)),
        }
        // gameplay.update_and_render(&sceneInstance, delta_time, &input_state, viewport)
        // gameplay.do_render(&sceneInstance, viewport)

        // if input.get_key_state(&input_state, sdl.Scancode.TAB) == input.Key_State_Pressed && !show_editor
        // {
        //     show_editor = true
        // }

        if input.get_key_state(&input_state, input.Input_Key.ESCAPE) == input.Key_State_Pressed
        {
            // if show_editor {
            //     show_editor = false
            // } else {
                running = false
            // } 
        }

        if input_state.quit do running = false
        
        // if show_editor
        // {
        //     editor.update_editor(&editor_state, viewport, &input_state)
        // }
        // imgui.render()
        imgui.button(
            &imgui_state, 
            imgui.I_Rect {
                pos = {10, 10},
                size = {100, 100},
            },
            &button_theme,
            platform_layer.gen_uid()
        )
        imgui.button(
            &imgui_state, 
            imgui.I_Rect {
                pos = {50, 70},
                size = {100, 100},
            },
            &button_theme,
            platform_layer.gen_uid(),
        )
        imgui.slider(
            &imgui_state,
            imgui.I_Rect {
                pos = {100, 70},
                size = {50, 200},
            },
            &font_scale, 0, 5,
            &slider_theme,
            platform_layer.gen_uid(),
        )

        scrollzone_rect := imgui.window_start(
            &imgui_state,
            &test_window_rect,
            600,
            &test_scroll_value,
            &window_theme,
            platform_layer.gen_uid(),
        )
        {
            scrollzone_rect.size.y = 50
            scrollzone_rect.pos.y += 5
            text_field_rect := scrollzone_rect
            text_field_rect.size.y = 60
            text_input_value = imgui.text_field(&imgui_state, text_field_rect, text_input_value, &caret_position, &text_field_theme, platform_layer.gen_uid())
            scrollzone_rect.pos.y += 60
            button_rect := scrollzone_rect
            for i in 0..<9 {
                rect_theme := platform_layer.Rect_Theme {
                    color = 0x11111100 * u32(i) + 0x000000ff
                }
                imgui.themed_rect(&imgui_state, scrollzone_rect, &rect_theme)
                scrollzone_rect.pos.y += 60
            }
            imgui.button(&imgui_state, button_rect, &button_theme, platform_layer.gen_uid())
            scrollzone_rect.pos.y += scrollzone_rect.size.y
            
            imgui.window_end(&imgui_state)
        }
        
        
        imgui.render_frame(&imgui_state, viewport)

        // imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state)
        // sdl.GL_SwapWindow(window)
        frame_duration := time.tick_diff(current_tick, time.tick_now())
        time.sleep(max(0, time.Millisecond * 16 - frame_duration))
    }
    // log.info("Shutting down...")
	// freetype.Done_FreeType(freetype_library)
}