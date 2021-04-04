package main

import "core:mem";
import "core:log";
import "core:strings";
import "core:runtime";
import "core:math";
import "core:math/linalg";
import "core:math/rand";
import "core:fmt"
import "core:time"

import sdl "shared:odin-sdl2";
import sdl_image "shared:odin-sdl2/image"
import gl  "shared:odin-gl";

import imgui "../libs/imgui";
import imgl  "../libs/impl/opengl";
import imsdl "../libs/impl/sdl";
import freetype "../libs/freetype"

import render "render";
import "util";
import "input"
import "gameplay"
import "editor"

DESIRED_GL_MAJOR_VERSION :: 4;
DESIRED_GL_MINOR_VERSION :: 5;
FRAME_SAMPLE_COUNT :: 10;


running := true;

vec2 :: [2]f32;
ivec2 :: [2]i32;

main :: proc() {
    logger_opts := log.Options {
        .Level,
        .Line,
        .Short_File_Path,
    };
    context.logger = log.create_console_logger(opt = logger_opts);

    log.info("Starting SDL Example...");
    
    init_err := sdl.init(.Video);
    defer sdl.quit();
    if init_err == 0 
    {
		log.info("load SDL_IMAGE");
        sdl_image.init(.PNG);
		freetype_library: freetype.Library;
		log.info("load Freetype");

		render.init_font_render();

        log.info("Setting up the window...");
        window := sdl.create_window("Ether", 100, 100, 1280, 720, .Open_GL|.Mouse_Focus|.Shown|.Resizable);
        if window == nil {
            log.debugf("Error during window creation: %s", sdl.get_error());
            sdl.quit();
            return;
        }
        defer sdl.destroy_window(window);

        log.info("Setting up the OpenGL...");
        sdl.gl_set_attribute(.Context_Major_Version, DESIRED_GL_MAJOR_VERSION);
        sdl.gl_set_attribute(.Context_Minor_Version, DESIRED_GL_MINOR_VERSION);
        sdl.gl_set_attribute(.Context_Profile_Mask, i32(sdl.GL_Context_Profile.Core));
        sdl.gl_set_attribute(.Doublebuffer, 1);
        sdl.gl_set_attribute(.Depth_Size, 24);
        sdl.gl_set_attribute(.Stencil_Size, 8);
        gl_ctx := sdl.gl_create_context(window);
        if gl_ctx == nil {
            log.debugf("Error during window creation: %s", sdl.get_error());
            return;
        }
        sdl.gl_make_current(window, gl_ctx);
        defer sdl.gl_delete_context(gl_ctx);
        if sdl.gl_set_swap_interval(1) != 0 {
            log.debugf("Error during window creation: %s", sdl.get_error());
            return;
        }
        gl.load_up_to(DESIRED_GL_MAJOR_VERSION, DESIRED_GL_MINOR_VERSION, proc(p: rawptr, name: cstring) do (cast(^rawptr)p)^ = sdl.gl_get_proc_address(name); );
        


        gl.ClearColor(0.25, 0.25, 0.25, 1);

        imgui_state := init_imgui_state(window);
        input_state : input.State;
        input.setup_state(&input_state);

        show_demo_window := false;
        io := imgui.get_io();
        screen_size: [2]int;

        sprite_database: render.Sprite_Database;
        render.init_sprite_database(&sprite_database, 5000, 5000);

        sceneInstance : gameplay.Scene;
        gameplay.init_main_scene(&sceneInstance, &sprite_database);


        editor_state: editor.Editor_State;
        show_editor := false;
        editor.init_editor(&editor_state, &sprite_database);

        last_frame_tick := time.tick_now();
        sample_frame_times: [FRAME_SAMPLE_COUNT]f32;
        frame_index := 0;


        for running {
            mx, my: i32;
            sdl.gl_get_drawable_size(window, &mx, &my);

            screen_size.x = cast(int)mx;
            screen_size.y = cast(int)my;
            
            input.new_frame(&input_state);
            input.process_events(&input_state);
            input.update_mouse(&input_state, window);
            input.update_display_size(window);

            imgui.new_frame();
            {
                info_overlay();
            }

            gl.Viewport(0, 0, mx, my);
            gl.Scissor(0, 0, mx, my);
            gl.Clear(gl.COLOR_BUFFER_BIT);

            current_tick := time.tick_now();
            delta_time := f32(time.duration_seconds(time.tick_diff(last_frame_tick, current_tick)));
            sample_frame_times[frame_index % FRAME_SAMPLE_COUNT] = delta_time;
            sample_time_sum: f32 = 0;
            for i in 0..<FRAME_SAMPLE_COUNT do sample_time_sum += sample_frame_times[i];
            frame_index += 1;
            last_frame_tick = current_tick;
            imgui.text_unformatted(fmt.tprint(FRAME_SAMPLE_COUNT / sample_time_sum));
            
            viewport := render.Viewport{
                {0, 0},
                screen_size,
            };
            gameplay.update_and_render(&sceneInstance, delta_time, &input_state, viewport);
            gameplay.do_render(&sceneInstance, viewport);

            if input.get_key_state(&input_state, sdl.Scancode.Tab) == input.Key_State_Pressed && !show_editor
            {
                show_editor = true;
            }

            if input.get_key_state(&input_state, sdl.Scancode.Escape) == input.Key_State_Pressed
            {
                if show_editor do show_editor = false else do running = false;
            }

            if input_state.quit do running = false;
            
            if show_editor
            {
                editor.update_editor(&editor_state, viewport, &input_state);
            }
            imgui.render();

            imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state);
            sdl.gl_swap_window(window);
            frame_duration := time.tick_diff(current_tick, time.tick_now());
            time.sleep(max(0, time.Millisecond * 16 - frame_duration));
        }
        log.info("Shutting down...");
		freetype.Done_FreeType(freetype_library);
        
    } else {
        log.debugf("Error during SDL init: (%d)%s", init_err, sdl.get_error());
    }
}

on_quit :: proc() {
    running = false;
}

info_overlay :: proc() {
    imgui.set_next_window_pos(imgui.Vec2{10, 10});
    imgui.set_next_window_bg_alpha(0.2);
    overlay_flags: imgui.Window_Flags = .NoDecoration | 
                                        .AlwaysAutoResize | 
                                        .NoSavedSettings | 
                                        .NoFocusOnAppearing | 
                                        .NoNav | 
                                        .NoMove;
    imgui.begin("Info", nil, overlay_flags);
    imgui.text_unformatted("Press Esc to close the application");
    imgui.end();
}

Imgui_State :: struct {
    opengl_state: imgl.OpenGL_State,
}

init_imgui_state :: proc(window: ^sdl.Window) -> Imgui_State {
    using res := Imgui_State{};
    
    imgui.create_context();
    imgui.style_colors_dark();
    
    imgl.setup_state(&res.opengl_state);

    return res;
}
