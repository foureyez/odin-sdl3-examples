package shadercross

import "core:c"
import sdl "vendor:sdl3"

when ODIN_OS == .Windows {
	foreign import lib "shadercross.lib"
} else {
	foreign import lib "lib/libSDL3_shadercross.a"
}

HLSLDefine :: struct {
	name:  cstring,
	value: cstring,
}

ShaderStage :: enum c.int {
	VERTEX,
	FRAGMENT,
	COMPUTE,
}

HLSLInfo :: struct {
	source:       cstring,
	entrypoint:   cstring,
	include_dir:  cstring,
	defines:      HLSLDefine,
	shader_stage: ShaderStage,
	enable_debug: bool,
	name:         cstring,
	props:        sdl.PropertiesID,
}

GraphicsShaderMetadata :: struct {
	num_samplers:         u32,
	num_storage_textures: u32,
	num_storage_buffers:  u32,
	num_uniform_buffers:  u32,
	props:                sdl.PropertiesID,
}

@(default_calling_convention = "c", link_prefix = "SDL_ShaderCross_", require_results)
foreign lib {
	Init :: proc() -> bool ---
	Quit :: proc() ---
	GetSPIRVShaderFormats :: proc() -> sdl.GPUShaderFormat ---
	CompileSPIRVFromHLSL :: proc(info: ^HLSLInfo, size: u32) ---
	CompileGraphicsShaderFromHLSL :: proc(device: ^sdl.GPUDevice, info: ^HLSLInfo, metadata: ^GraphicsShaderMetadata) -> ^sdl.GPUShader ---
}
