package render

import gl "shared:odin-gl"
import "core:log"

// Bindless Texture
impl_GetTextureHandleARB:               proc "c" (texture: u32) -> u64;
impl_GetTextureSamplerHandle:           proc "c" (texture: u32, sampler: u32) -> u64;
impl_MakeTextureHandleResidentARB:      proc "c" (handle: u64);
impl_MakeTextureHandleNonResidentARB:   proc "c" (handle: u64);
impl_GetImageHandleARB:                 proc "c" (texture: u32, level: i32, layered: u8, layer: i32, format: u32) -> u64;
impl_MakeImageHandleResidentARB:        proc "c" (handle: u64, access: i32);
impl_MakeImageHandleNonResidentARB:     proc "c" (handle: u64);
impl_UniformHandleui64ARB:              proc "c" (location: i32, value: u64);
impl_UniformHandleui64vARB:             proc "c" (location: i32, count: i32, value: ^u64);
impl_ProgramUniformHandleui64ARB:       proc "c" (program: u32, location: i32, count: i32, values: ^u64);
impl_ProgramUniformHandleui64vARB:      proc "c" (program: u32, location: i32, count: i32, values: ^u64);
impl_IsTextureHandleResidentARB:        proc "c" (handle: u64) -> u8;
impl_IsImageHandleResidentARB:          proc "c" (handle: u64) -> u8;
impl_VertexAttribL1ui64ARB:             proc "c" (program: u32, location: i32, count: i32, values: ^u64);
impl_VertexAttribL1ui64vARB:            proc "c" (handle: u64) -> u8;
impl_GetVertexAttribLui64vARB:          proc "c" (handle: u64) -> u8;

load_ARB_bindless_texture :: proc(set_proc_address: gl.Set_Proc_Address_Type) {
    set_proc_address(&impl_GetTextureHandleARB,              "glGetTextureHandleARB");
    set_proc_address(&impl_GetTextureSamplerHandle,          "glGetTextureSamplerHandleARB");
    set_proc_address(&impl_MakeTextureHandleResidentARB,     "glMakeTextureHandleResidentARB");
    set_proc_address(&impl_MakeTextureHandleNonResidentARB,  "glMakeTextureHandleNonResidentARB");
    set_proc_address(&impl_GetImageHandleARB,                "glGetImageHandleARB");
    set_proc_address(&impl_MakeImageHandleResidentARB,       "glMakeImageHandleResidentARB");
    set_proc_address(&impl_MakeImageHandleNonResidentARB,    "glMakeImageHandleNonResidentARB");
    set_proc_address(&impl_UniformHandleui64ARB,             "glUniformHandleui64ARB");
    set_proc_address(&impl_UniformHandleui64vARB,            "glUniformHandleui64vARB");
    set_proc_address(&impl_ProgramUniformHandleui64ARB,      "glProgramUniformHandleui64ARB");
    set_proc_address(&impl_ProgramUniformHandleui64vARB,     "glProgramUniformHandleui64vARB");
    set_proc_address(&impl_IsTextureHandleResidentARB,       "glIsTextureHandleResidentARB");
    set_proc_address(&impl_IsImageHandleResidentARB,         "glIsImageHandleResidentARB");
    set_proc_address(&impl_VertexAttribL1ui64ARB,            "glVertexAttribL1ui64ARB");
    set_proc_address(&impl_VertexAttribL1ui64vARB,           "glVertexAttribL1ui64vARB");
    set_proc_address(&impl_GetVertexAttribLui64vARB,         "glGetVertexAttribLui64vARB");
}

when !ODIN_DEBUG
{
	GetTextureHandleARB :: #force_inline proc "c" (texture: u32) -> u64 { return impl_GetTextureHandleARB(texture);}
	GetTextureSamplerHandleARB :: #force_inline proc "c" (texture: u32, sampler: u32) -> u64 { return impl_GetTextureSamplerHandle(texture, sampler); }
	MakeTextureHandleResidentARB :: #force_inline proc "c" (handle: u64) { impl_MakeTextureHandleResidentARB(handle); }
	MakeTextureHandleNonResidentARB :: #force_inline proc "c" (handle: u64) { impl_MakeTextureHandleNonResidentARB(handle); }
	GetImageHandleARB :: #force_inline proc "c" (texture: u32, level: i32, layered: u8, layer: i32, format: u32) -> u64 { return impl_GetImageHandleARB(texture, level, layered, layer, format); }
	MakeImageHandleResidentARB :: #force_inline proc "c" (handle: u64, access: i32) { impl_MakeImageHandleResidentARB(handle, access); }
	MakeImageHandleNonResidentARB :: #force_inline proc "c" (handle: u64) { impl_MakeImageHandleNonResidentARB(handle); }
	UniformHandleui64ARB :: #force_inline proc "c" (location: i32, value: u64) { impl_UniformHandleui64ARB(location, value); }
	UniformHandleui64vARB :: #force_inline proc "c" (location: i32, count: i32, value: ^u64) { impl_UniformHandleui64vARB(location, count, value); }
	ProgramUniformHandleui64ARB :: #force_inline proc "c" (program: u32, location: i32, count: i32, values: ^u64) { impl_ProgramUniformHandleui64ARB(program, location, count, values); }
	ProgramUniformHandleui64vARB :: #force_inline proc "c" (program: u32, location: i32, count: i32, values: ^u64) { impl_ProgramUniformHandleui64vARB(program, location, count, values); }
	IsTextureHandleResidentARB :: #force_inline proc "c" (handle: u64) -> u8 { return impl_IsTextureHandleResidentARB(handle); }
	IsImageHandleResidentARB :: #force_inline proc "c" (handle: u64) -> u8 { return impl_IsImageHandleResidentARB(handle); }
	VertexAttribL1ui64ARB :: #force_inline proc "c" (program: u32, location: i32, count: i32, values: ^u64) { impl_VertexAttribL1ui64ARB(program, location, count, values); }
	VertexAttribL1ui64vARB :: #force_inline proc "c" (handle: u64) -> u8 { return impl_VertexAttribL1ui64vARB(handle); }
	GetVertexAttribLui64vARB :: #force_inline proc "c" (handle: u64) -> u8 { return impl_GetVertexAttribLui64vARB(handle); }

}
else
{
	GetTextureHandleARB :: #force_inline proc (texture: u32, loc := #caller_location) -> u64 
	{ 
		result := impl_GetTextureHandleARB(texture);
		log.info(result);
		gl.debug_helper(loc, 1, result, texture);
		return result; 
	}
	
	GetTextureSamplerHandle :: #force_inline proc "c" (texture: u32, sampler: u32, loc := #caller_location) -> u64
	{
		result := impl_GetTextureSamplerHandle(texture, sampler);
		gl.debug_helper(loc, 1, result, texture, sampler);
		return result;
	}
	
	MakeTextureHandleResidentARB :: #force_inline proc "c" (handle: u64, loc := #caller_location)
	{
		impl_MakeTextureHandleResidentARB(handle);
		gl.debug_helper(loc, 0, handle);
	}

	MakeTextureHandleNonResidentARB :: #force_inline proc "c" (handle: u64, loc := #caller_location)
	{
		impl_MakeTextureHandleNonResidentARB(handle);
		gl.debug_helper(loc, 0, handle);
	}

	GetImageHandleARB :: #force_inline proc "c" (texture: u32, level: i32, layered: u8, layer: i32, format: u32, loc:= #caller_location) -> u64
	{
		result := impl_GetImageHandleARB(texture, level, layered, layer, format);
		gl.debug_helper(loc, 1, result, texture, level, layered, layer, format);
		return result;
	}

	MakeImageHandleResidentARB :: #force_inline proc "c" (handle: u64, access: i32, loc:= #caller_location)
	{
		impl_MakeImageHandleResidentARB(handle, access);
		gl.debug_helper(loc, 0, handle, access);
	}

	MakeImageHandleNonResidentARB :: #force_inline proc "c" (handle: u64, loc:= #caller_location)
	{
		impl_MakeImageHandleNonResidentARB(handle);
		gl.debug_helper(loc, 0, handle);
	}

	UniformHandleui64ARB :: #force_inline proc "c" (location: i32, value: u64, loc := #caller_location)
	{
		impl_UniformHandleui64ARB(location, value);
		gl.debug_helper(loc, 0, location, value);
	}

	UniformHandleui64vARB :: #force_inline proc "c" (location: i32, count: i32, value: ^u64, loc := #caller_location)
	{
		impl_UniformHandleui64vARB(location, count, value);
		gl.debug_helper(loc, 0, location, count, value);
	}

	ProgramUniformHandleui64ARB :: #force_inline proc "c" (program: u32, location: i32, count: i32, values: ^u64, loc := #caller_location)
	{
		impl_ProgramUniformHandleui64ARB(program, location, count, values);
		gl.debug_helper(loc, 0, program, location, count, values);
	}

	ProgramUniformHandleui64vARB :: #force_inline proc "c" (program: u32, location: i32, count: i32, values: ^u64, loc:= #caller_location)
	{
		impl_ProgramUniformHandleui64vARB(program, location, count, values);
		gl.debug_helper(loc, 0, program, location, count, values);
	}

	IsTextureHandleResidentARB :: #force_inline proc "c" (handle: u64, loc:= #caller_location) -> u8
	{
		result := impl_IsTextureHandleResidentARB(handle);
		gl.debug_helper(loc, 1, result, handle);
		return result;
	}

	IsImageHandleResidentARB :: #force_inline proc "c" (handle: u64, loc := #caller_location) -> u8
	{
		result := impl_IsImageHandleResidentARB(handle);
		gl.debug_helper(loc, 1, result, handle);
		return result;
	}

	VertexAttribL1ui64ARB :: #force_inline proc "c" (program: u32, location: i32, count: i32, values: ^u64, loc := #caller_location)
	{
		impl_VertexAttribL1ui64ARB(program, location, count, values);
		gl.debug_helper(loc, 0, program, location, count, values);
	}

	VertexAttribL1ui64vARB :: #force_inline proc "c" (handle: u64, loc := #caller_location) -> u8
	{
		result := impl_VertexAttribL1ui64vARB(handle);
		gl.debug_helper(loc, 1, result, handle);
		return result;
	}

	GetVertexAttribLui64vARB :: #force_inline proc "c" (handle: u64, loc := #caller_location) -> u8
	{
		result := impl_GetVertexAttribLui64vARB(handle);
		gl.debug_helper(loc, 1, result, handle);
		return result;
	}


}
