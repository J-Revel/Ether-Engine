package util

import "core:runtime"
import "core:fmt"

import "core:log";
import "core:strings";

import imgui "../../libs/imgui";

imgui_editor :: proc(var : any)
{
    type_info := type_info_of(var.id);
    #partial switch variant in type_info.variant
    {
        case runtime.Type_Info_Struct:
            imgui.text_unformatted("struct");
            imgui.text_unformatted("{");
            structInfo, ok := type_info.variant.(runtime.Type_Info_Struct);
            for _, i in structInfo.names
            {
                imgui.push_id(structInfo.names[i]);
                imgui.text_unformatted(structInfo.names[i]);
                field := rawptr(uintptr(var.data) + structInfo.offsets[i]);
                imgui_editor({field, structInfo.types[i].id});
                imgui.pop_id();
            }
            imgui.text_unformatted("}");
            return;
        case runtime.Type_Info_Any:
            imgui.text_unformatted("Any");
            return;
        case runtime.Type_Info_Named:
            imgui.text_unformatted("Named");
            
            imgui.text_unformatted("{");
            imgui_editor({var.data, variant.base.id});
            imgui.text_unformatted("}");
            return;
        case runtime.Type_Info_Integer:
            imgui.slider_int("x", cast(^i32) var.data, 0, 100);
            return;
        case runtime.Type_Info_Float:
            imgui.slider_float("x", cast(^f32) var.data, 0, 100);
            return;
    }
    //imgui.text_unformatted(type_info.variant);
}