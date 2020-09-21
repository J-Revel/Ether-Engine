package main

import "core:mem";
import "core:log";
import "core:strings";
import "core:runtime";
import "core:math";
import "core:math/linalg";
import "core:math/rand";

import sdl "shared:odin-sdl2";
import gl  "shared:odin-gl";

import imgui "imgui";
import imgl  "impl/opengl";
import imsdl "impl/sdl";

import render "src/render";
import "src/util";
import "src/geometry"
import "src/input"
import "src:gameplay"

DESIRED_GL_MAJOR_VERSION :: 4;
DESIRED_GL_MINOR_VERSION :: 5;


running := true;

vec2 :: [2]f32;
ivec2 :: [2]i32;

main :: proc() {
    logger_opts := log.Options {
        .Level,
        .Line,
        .Procedure,
    };
    context.logger = log.create_console_logger(opt = logger_opts);
    log.info("Starting SDL Example...");
    init_err := sdl.init(.Video);
    defer sdl.quit();
    if init_err == 0 {
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
        gl.load_up_to(DESIRED_GL_MAJOR_VERSION, DESIRED_GL_MINOR_VERSION, 
                      proc(p: rawptr, name: cstring) do (cast(^rawptr)p)^ = sdl.gl_get_proc_address(name); );
        gl.ClearColor(0.25, 0.25, 0.25, 1);

        imgui_state := init_imgui_state(window);
        input_state : input.State;
        input.setup_state(&input_state);

        render_buffer: render.Render_System;
        
        //building.size = vec2{20, 20};

        render.initRenderer(&render_buffer.render_state);

        show_demo_window := false;
        io := imgui.get_io();
        screenSize : vec2;

        sceneInstance : gameplay.Scene;
        gameplay.init_scene(&sceneInstance);

        for running {
            mx, my: i32;
            sdl.gl_get_drawable_size(window, &mx, &my);

            screenSize.x = cast(f32)mx;
            screenSize.y = cast(f32)my;
            render_buffer.screen_size = screenSize;
            input.new_frame(&input_state);
            input.process_events(&input_state);
            input.update_mouse(&input_state, window);
            input.update_display_size(window);

            imgui.new_frame();
            {
                info_overlay();
            }

            gl.Viewport(0, 0, i32(io.display_size.x), i32(io.display_size.y));
            gl.Scissor(0, 0, i32(io.display_size.x), i32(io.display_size.y));
            gl.Clear(gl.COLOR_BUFFER_BIT);
            gameplay.update_and_render(&sceneInstance, 1.0/60, &render_buffer, &input_state);
            imgui.render();

            
            if(input_state.quit || input.get_key_state(&input_state, sdl.Scancode.Escape) == .Pressed)
                do running = false;

            imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state);;
            render.clearRenderBuffer(&render_buffer);
            sdl.gl_swap_window(window);
        }
        log.info("Shutting down...");
        
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

text_test_window :: proc() {
    imgui.begin("Text test");
    imgui.text("NORMAL TEXT: {}", 1);
    imgui.text_colored(imgui.Vec4{1, 0, 0, 1}, "COLORED TEXT: {}", 2);
    imgui.text_disabled("DISABLED TEXT: {}", 3);
    imgui.text_unformatted("UNFORMATTED TEXT");
    imgui.text_wrapped("WRAPPED TEXT: {}", 4);
    imgui.end();
}

input_text_test_window :: proc() {
    imgui.begin("Input text test");
    @static buf: [256]u8;
    @static ok := false;
    imgui.input_text("Test input", buf[:]);
    imgui.input_text("Test password input", buf[:], .Password);
    if imgui.input_text("Test returns true input", buf[:], .EnterReturnsTrue) {
        ok = !ok;
    }
    imgui.checkbox("OK?", &ok);
    imgui.text_wrapped("Buf content: %s", string(buf[:]));
    imgui.end();
}

misc_test_window :: proc() {
    imgui.begin("Misc tests");
    pos := imgui.get_window_pos();
    size := imgui.get_window_size();
    imgui.text("pos: {}", pos);
    imgui.text("size: {}", size);
    imgui.end();
}

combo_test_window :: proc() {
    imgui.begin("Combo tests");
    @static items := []string {"1", "2", "3"};
    @static curr_1 := i32(0);
    @static curr_2 := i32(1);
    @static curr_3 := i32(2);
    if imgui.begin_combo("begin combo", items[curr_1]) {
        for item, idx in items {
            is_selected := idx == int(curr_1);
            if imgui.selectable(item, is_selected) {
                curr_1 = i32(idx);
            }

            if is_selected {
                imgui.set_item_default_focus();
            }
        }
        defer imgui.end_combo();
    }

    imgui.combo_str_arr("combo str arr", &curr_2, items);

    item_getter : imgui.Items_Getter_Proc : proc "c" (data: rawptr, idx: i32, out_text: ^cstring) -> bool {
        context = runtime.default_context();
        items := (cast(^[]string)data);
        out_text^ = strings.clone_to_cstring(items[idx], context.temp_allocator);
        return true;
    }

    imgui.combo_fn_bool_ptr("combo fn ptr", &curr_3, item_getter, &items, i32(len(items)));

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