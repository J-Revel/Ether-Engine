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

import "src/gameplay/planet"
import "src/gameplay/entity"
import "src/geometry"
import "src/input"

DESIRED_GL_MAJOR_VERSION :: 4;
DESIRED_GL_MINOR_VERSION :: 5;


running := true;
mouse_pressed := false;
buildings: [dynamic]entity.Building;
building: entity.Building;

vec2 :: [2]f32;

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

        renderer: render.RendererState;
        renderBuffer: render.RenderBuffer;

        planets: [dynamic]planet.Instance;
        for j := 0; j<10; j += 1
        {
            planetConfig : planet.Instance;
            planetConfig.pos = vec2{cast(f32)((j % 10) * 10000), cast(f32)((j / 10) * 10000)};
            planetConfig.r = 1000;
            harmonic :=  planet.ShapeHarmonic{0.2, 1};
            for i := 0; i<10; i+=1
            {
                harmonic.f = rand.float32() / cast(f32) (i + 1);
                harmonic.offset = rand.float32() * 2 * math.PI;
                append(&planetConfig.harmonics, harmonic);
                    
            }
            append(&planets, planetConfig);
        }
        
        building.size = vec2{20, 20};
        building.planet = &planets[0];

        camera : render.Camera;
        camera.zoom = 1;
        render.initRenderer(&renderer);

        show_demo_window := false;
        lastMousePos := vec2{0, 0};
        io := imgui.get_io();
        mousePos : vec2;
        screenSize : vec2;

        append(&input.active_delegates.quit, on_quit);
        append(&input.active_delegates.key_state_changed, on_key_press);
        append(&input.active_delegates.button_state_changed, on_button_press);
        for running {
            mx, my: i32;
            sdl.get_mouse_state(&mx, &my);
            mousePos.x = cast(f32)mx;
            mousePos.y = cast(f32)my;
            sdl.gl_get_drawable_size(window, &mx, &my);

            screenSize.x = cast(f32)mx;
            screenSize.y = cast(f32)my;
            input.handle_input();
            

            imgui_new_frame(window, &imgui_state);
            imgui.new_frame();
            {
                info_overlay();

                if show_demo_window do imgui.show_demo_window(&show_demo_window);
                
                text_test_window();
                input_text_test_window();
                misc_test_window();
                combo_test_window();
            }
            imgui.render();

            gl.Viewport(0, 0, i32(io.display_size.x), i32(io.display_size.y));
            gl.Scissor(0, 0, i32(io.display_size.x), i32(io.display_size.y));
            gl.Clear(gl.COLOR_BUFFER_BIT);
            
            //mousePos := vec2{-io.mouse_pos.x, io.mouse_pos.y};
            if(mouse_pressed)
            {
                offset := mousePos - lastMousePos;
                camera.pos.x -= offset.x;
                camera.pos.y += offset.y;
            }
            lastMousePos = mousePos;
            worldMousePos := [2]f32{mousePos.x + camera.pos.x - screenSize.x / 2, -mousePos.y + camera.pos.y + screenSize.y / 2};
            for planetInstance in &planets
            {
                if(linalg.vector_length(worldMousePos - planetInstance.pos) < linalg.vector_length(worldMousePos - building.planet.pos))
                {
                    building.planet = &planetInstance;
                }
            }
            building.angle = planet.closestSurfaceAngle(building.planet, worldMousePos, 100);
            for planetInstance in &planets do
                planet.render(&renderBuffer, &(planets[0]), 500);
            entity.renderBuilding(&building, &renderBuffer);
            for building in &buildings do
                entity.renderBuilding(&building, &renderBuffer);
            render.renderBufferContent(&renderer, &renderBuffer, &camera, vec2{screenSize.x, screenSize.y});
            render.clearRenderBuffer(&renderBuffer);
            imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state);
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

on_key_press :: proc(key: sdl.Keysym, state: input.Input_State) -> bool
{
    if(key.scancode == .Escape)
    {
        running = false;
        return true;
    }
    return false;
}

on_button_press :: proc(button: u8, pos: vec2, state: input.Input_State) -> bool
{
    append(&buildings, building);
    mouse_pressed = (state == .Down);
    return true;
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
    imgui.text_unformatted("Press Tab to show demo window");
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

is_key_down :: proc(e: sdl.Event, sc: sdl.Scancode) -> bool {
    return e.key.type == .Key_Down && e.key.keysym.scancode == sc;
}

Imgui_State :: struct {
    sdl_state: imsdl.SDL_State,
    opengl_state: imgl.OpenGL_State,
}

init_imgui_state :: proc(window: ^sdl.Window) -> Imgui_State {
    using res := Imgui_State{};

    imgui.create_context();
    imgui.style_colors_dark();

    imsdl.setup_state(&res.sdl_state);
    
    imgl.setup_state(&res.opengl_state);

    return res;
}

imgui_new_frame :: proc(window: ^sdl.Window, state: ^Imgui_State) {
    imsdl.update_display_size(window);
    imsdl.update_mouse(&state.sdl_state, window);
    imsdl.update_dt(&state.sdl_state);
}
