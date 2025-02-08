package common

import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:strings"
import sdl "vendor:sdl3"

load_shader :: proc(
	device: ^sdl.GPUDevice,
	shader_filename: string,
	sampler_count: u32,
	uniform_buffer_count: u32,
	storage_buffer_count: u32,
	storage_texture_count: u32,
) -> ^sdl.GPUShader {

	stage: sdl.GPUShaderStage
	switch {
	case strings.contains(shader_filename, ".vert"):
		stage = .VERTEX
	case strings.contains(shader_filename, ".frag"):
		stage = .FRAGMENT
	case:
		return nil
	}

	full_path: string
	format: sdl.GPUShaderFormat = {}
	entrypoint: cstring

	backend_formats := sdl.GetGPUShaderFormats(device)
	switch {
	case .SPIRV in backend_formats:
		full_path = fmt.tprintf("./Content/Shaders/Compiled/SPIRV/%s.spv", shader_filename)
		entrypoint = "main"
		format = {.SPIRV}
	case .MSL in backend_formats:
		full_path = fmt.tprintf("./Content/Shaders/Compiled/SPIRV/%s.msl", shader_filename)
		entrypoint = "main"
		format = {.MSL}
	case .DXIL in backend_formats:
		full_path = fmt.tprintf("./Content/Shaders/Compiled/SPIRV/%s.dxil", shader_filename)
		entrypoint = "main"
		format = {.DXIL}
	}

	code, err := os.read_entire_file(full_path, context.temp_allocator)
	if err != nil {
		log.errorf("unable to open shader file: %s", full_path)
		return nil
	}

	shader_create_info: sdl.GPUShaderCreateInfo = {
		code                 = raw_data(code),
		code_size            = len(code),
		entrypoint           = entrypoint,
		format               = format,
		stage                = stage,
		num_samplers         = sampler_count,
		num_uniform_buffers  = uniform_buffer_count,
		num_storage_buffers  = storage_buffer_count,
		num_storage_textures = storage_texture_count,
	}

	gpu_shader := sdl.CreateGPUShader(device, shader_create_info)
	if gpu_shader == nil {
		log.errorf("unable to create gpu shader, error: %s", sdl.GetError())
	}
	return gpu_shader
}
