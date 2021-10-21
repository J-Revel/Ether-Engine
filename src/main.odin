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

import sdl "vendor:sdl2";
import sdl_image "vendor:sdl2/image"
import gl  "vendor:OpenGL";

import freetype "../libs/freetype"

import render "render";
import "util";
import "input"
import "gameplay"

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
    
    init_err := sdl.Init(sdl.INIT_VIDEO | sdl.INIT_AUDIO);
    defer sdl.Quit();
    if init_err == 0 
    {
		log.info("load SDL_IMAGE");
        sdl_image.Init(sdl_image.INIT_PNG);
		log.info("load Freetype");

		render.init_font_render();

        log.info("Setting up the window...");
        window := sdl.CreateWindow("Ether", 100, 100, 1280, 720, sdl.WindowFlags{.OPENGL, .MOUSE_FOCUS, .SHOWN, .RESIZABLE});
        if window == nil {
            log.debugf("Error during window creation: %s", sdl.GetError());
            sdl.Quit();
            return;
        }
        defer sdl.DestroyWindow(window);

        log.info("Setting up the OpenGL...");
        sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_GL_MAJOR_VERSION);
        sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_GL_MINOR_VERSION);
        sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE));
        sdl.GL_SetAttribute(.DOUBLEBUFFER, 1);
        sdl.GL_SetAttribute(.DEPTH_SIZE, 24);
        sdl.GL_SetAttribute(.STENCIL_SIZE, 8);
        gl_ctx := sdl.GL_CreateContext(window);
        if gl_ctx == nil {
            log.debugf("Error during window creation: %s", sdl.GetError());
            return;
        }
        sdl.GL_MakeCurrent(window, gl_ctx);
        defer sdl.GL_DeleteContext(gl_ctx);
        if sdl.GL_SetSwapInterval(1) != 0 {
            log.debugf("Error during window creation: %s", sdl.GetError());
            return;
        }
		load_proc := proc(p: rawptr, name: cstring) do (cast(^rawptr)p)^ = sdl.GL_GetProcAddress(name);
        gl.load_up_to(DESIRED_GL_MAJOR_VERSION, DESIRED_GL_MINOR_VERSION, load_proc);

		render.load_ARB_bindless_texture(load_proc);
		test_frequency : f32 = 440;
		
		// audio_system: audio.Audio_System;
		// audio.init_audio_system(&audio_system);
        gl.ClearColor(0.25, 0.25, 0.25, 1);

        input_state : input.State;
        //input.setup_state(&input_state);

        show_demo_window := false;
        screen_size: [2]int;

        sprite_database: render.Sprite_Database;
        render.init_sprite_database(&sprite_database, 5000, 5000);

        sceneInstance : gameplay.Scene;
        gameplay.init_main_scene(&sceneInstance, &sprite_database);

        // editor_state: editor.Editor_State;
        show_editor := false;
        // editor.init_editor(&editor_state, &sprite_database);

        last_frame_tick := time.tick_now();
        sample_frame_times: [FRAME_SAMPLE_COUNT]f32;
        frame_index := 0;


        for running {
			err := gl.GetError();
			for err != gl.NO_ERROR
			{
				log.error("OPENGL ERROR", err);
				err = gl.GetError();
			}
            mx, my: i32;
            sdl.GL_GetDrawableSize(window, &mx, &my);

            screen_size.x = cast(int)mx;
            screen_size.y = cast(int)my;
            
            input.new_frame(&input_state);
            input.process_events(&input_state);
            input.update_mouse(&input_state, window);
            input.update_display_size(window);

            {
                //info_overlay();
            }

            gl.Viewport(0, 0, mx, my);
            gl.Scissor(0, 0, mx, my);
            gl.Clear(gl.COLOR_BUFFER_BIT);

            current_tick := time.tick_now();
            delta_time := f32(time.duration_seconds(time.tick_diff(last_frame_tick, current_tick)));
            sample_frame_times[frame_index % FRAME_SAMPLE_COUNT] = delta_time;
			util.register_frame_sample(delta_time);
            last_frame_tick = current_tick;
            
            viewport := render.Viewport{
                {0, 0},
                screen_size,
            };
            gameplay.update_and_render(&sceneInstance, delta_time, &input_state, viewport);
            gameplay.do_render(&sceneInstance, viewport);

            if input.get_key_state(&input_state, sdl.Scancode.TAB) == input.Key_State_Pressed && !show_editor
            {
                show_editor = true;
            }

            if input.get_key_state(&input_state, sdl.Scancode.ESCAPE) == input.Key_State_Pressed
            {
                if show_editor do show_editor = false else do running = false;
            }

            if input_state.quit do running = false;
            
            // if show_editor
            // {
            //     editor.update_editor(&editor_state, viewport, &input_state);
            // }
            sdl.GL_SwapWindow(window);
            frame_duration := time.tick_diff(current_tick, time.tick_now());
            time.sleep(max(0, time.Millisecond * 16 - frame_duration));
        }
        log.info("Shutting down...");
        
    } else {
        log.debugf("Error during SDL init: (%d)%s", init_err, sdl.GetError());
    }
}

on_quit :: proc() {
    running = false;
}

