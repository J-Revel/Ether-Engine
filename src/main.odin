package main

import "core:mem"
import "core:log"
import "core:strings"
import "core:runtime"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:fmt"
import "core:time"

import sdl "vendor:sdl2"
import sdl_image "vendor:sdl2/image"
import gl  "vendor:OpenGL"

import "input"
import "render"
import "imgui"

DESIRED_GL_MAJOR_VERSION :: 4
DESIRED_GL_MINOR_VERSION :: 5
FRAME_SAMPLE_COUNT :: 10

default_screen_size :: [2]i32{1280, 720}


running := true

vec2 :: [2]f32
ivec2 :: [2]i32

main :: proc() {
    logger_opts := log.Options {
        .Level,
        .Line,
        .Short_File_Path,
    }
    context.logger = log.create_console_logger(opt = logger_opts)

    log.info("Starting SDL Example...")
    
    init_err := sdl.Init(sdl.INIT_VIDEO | sdl.INIT_AUDIO)
    defer sdl.Quit()
    if init_err == 0 
    {
		log.info("load SDL_IMAGE")
        sdl_image.Init(sdl_image.INIT_PNG)

		// render.init_font_render()

        log.info("Setting up the window...")
        
        window := sdl.CreateWindow("Ether", 100, 100, default_screen_size.x, default_screen_size.y, sdl.WINDOW_OPENGL|sdl.WINDOW_MOUSE_FOCUS|sdl.WINDOW_SHOWN|sdl.WINDOW_RESIZABLE)
        if window == nil {
            log.debugf("Error during window creation: %s", sdl.GetError())
            sdl.Quit()
            return
        }
        defer sdl.DestroyWindow(window)

        log.info("Setting up the OpenGL...")
        sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_GL_MAJOR_VERSION)
        sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_GL_MINOR_VERSION)
        sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE))
        sdl.GL_SetAttribute(.DOUBLEBUFFER, 1)
        sdl.GL_SetAttribute(.DEPTH_SIZE, 24)
        sdl.GL_SetAttribute(.STENCIL_SIZE, 8)
        gl_ctx := sdl.GL_CreateContext(window)
        if gl_ctx == nil {
            log.debugf("Error during window creation: %s", sdl.GetError())
            return
        }
        sdl.GL_MakeCurrent(window, gl_ctx)
        defer sdl.GL_DeleteContext(gl_ctx)
        if sdl.GL_SetSwapInterval(1) != 0 {
            log.debugf("Error during window creation: %s", sdl.GetError())
            return
        }
		load_proc := proc(p: rawptr, name: cstring) {
            (cast(^rawptr)p)^ = sdl.GL_GetProcAddress(name)
        } 
        gl.load_up_to(DESIRED_GL_MAJOR_VERSION, DESIRED_GL_MINOR_VERSION, load_proc)

		render.load_ARB_bindless_texture(load_proc)
		test_frequency : f32 = 440
		
		// audio_system: audio.Audio_System
		// audio.init_audio_system(&audio_system)
        gl.ClearColor(0, 0.25, 0.25, 1)

        // imgui_state := init_imgui_state(window)
        input_state : input.State

        // show_demo_window := false
        // io := imgui.get_io()
        screen_size: [2]int

        sprite_database: render.Sprite_Database
        render.init_sprite_database(&sprite_database, 5000, 5000)

        // sceneInstance : gameplay.Scene
        // gameplay.init_main_scene(&sceneInstance, &sprite_database)

        // editor_state: editor.Editor_State
        // show_editor := false
        // editor.init_editor(&editor_state, &sprite_database)

        imgui_state: imgui.UI_State = {
            input_state = &input_state,
        }
        viewport := imgui.I_Rect{
            {0, 0},
            default_screen_size,
        }
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
        window_background_theme: imgui.Rect_Theme = {
            color = 0x333333ff,
        }
        scrollzone_theme: imgui.Scrollzone_Theme = {
            &slider_theme,
            &window_background_theme,
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
        window_theme: imgui.Window_Theme = {
            &scrollzone_theme,
            30,
            &header_theme,
        }
        
        last_frame_tick := time.tick_now()
        sample_frame_times: [FRAME_SAMPLE_COUNT]f32
        frame_index := 0

        test_slider_value := 0
        test_scroll_value : i32 = 0
        test_window_rect := imgui.I_Rect {
            pos = {200, 100},
            size = {500, 300},
        }

        for running {
			err := gl.GetError()
			for err != gl.NO_ERROR
			{
				log.error("OPENGL ERROR", err)
				err = gl.GetError()
			}
            mx, my: i32
            sdl.GL_GetDrawableSize(window, &mx, &my)

            screen_size.x = cast(int)mx
            screen_size.y = cast(int)my
            
            input.new_frame(&input_state)
            input.process_events(&input_state)
            input.update_mouse(&input_state, window)
            // input.update_display_size(window)

            // imgui.new_frame()
            // {
            //     info_overlay()
            // }

            gl.Viewport(0, 0, mx, my)
            gl.Scissor(0, 0, mx, my)
            gl.Clear(gl.COLOR_BUFFER_BIT)
            gl.Enable(gl.BLEND);
	        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

            current_tick := time.tick_now()
            delta_time := f32(time.duration_seconds(time.tick_diff(last_frame_tick, current_tick)))
            sample_frame_times[frame_index % FRAME_SAMPLE_COUNT] = delta_time
            sample_time_sum: f32 = 0
            for i in 0..<FRAME_SAMPLE_COUNT do sample_time_sum += sample_frame_times[i]
            frame_index += 1
            last_frame_tick = current_tick
            
            viewport = imgui.I_Rect{
                {0, 0},
                {mx, my},
            }
            // gameplay.update_and_render(&sceneInstance, delta_time, &input_state, viewport)
            // gameplay.do_render(&sceneInstance, viewport)

            // if input.get_key_state(&input_state, sdl.Scancode.TAB) == input.Key_State_Pressed && !show_editor
            // {
            //     show_editor = true
            // }

            if input.get_key_state(&input_state, sdl.Scancode.ESCAPE) == input.Key_State_Pressed
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
                imgui.gen_uid()
            )
            imgui.button(
                &imgui_state, 
                imgui.I_Rect {
                    pos = {50, 70},
                    size = {100, 100},
                },
                &button_theme,
                imgui.gen_uid(),
            )
            imgui.slider(
                &imgui_state,
                imgui.I_Rect {
                    pos = {100, 70},
                    size = {50, 200},
                },
                &test_slider_value, 0, 100,
                &slider_theme,
                imgui.gen_uid(),
            )

            imgui.slider(
                &imgui_state,
                imgui.I_Rect {
                    pos = {70, 100},
                    size = {50, 300},
                },
                &test_slider_value, 0, 100,
                &slider_theme,
                imgui.gen_uid(),
            )
            scrollzone_rect := imgui.window_start(
                &imgui_state,
                &test_window_rect,
                600,
                &test_scroll_value,
                &window_theme,
                imgui.gen_uid(),
            )
            {
                scrollzone_rect.size.y = 50
                scrollzone_rect.pos.y += 5
                button_rect := scrollzone_rect
                for i in 0..<10 {
                    rect_theme := imgui.Rect_Theme {
                        color = 0x11111100 * u32(i) + 0x000000ff
                    }
                    imgui.themed_rect(&imgui_state, scrollzone_rect, &rect_theme)
                    scrollzone_rect.pos.y += 60
                }
                imgui.button(&imgui_state, button_rect, &button_theme, imgui.gen_uid())
                imgui.window_end(&imgui_state)
            }
            
            imgui.render_frame(&imgui_state, viewport)

            // imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state)
            sdl.GL_SwapWindow(window)
            frame_duration := time.tick_diff(current_tick, time.tick_now())
            time.sleep(max(0, time.Millisecond * 16 - frame_duration))
        }
        log.info("Shutting down...")
		// freetype.Done_FreeType(freetype_library)
        
    } else {
        log.debugf("Error during SDL init: (%d)%s", init_err, sdl.GetError())
    }
}