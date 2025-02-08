package examples

import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:strings"
import sdl "vendor:sdl3"

ctx: SDLContext
viewport := sdl.GPUViewport{0, 0, 640, 480, 0.1, 1.0}
scissor_rect := sdl.Rect{320, 240, 320, 240}

SDLContext :: struct {
	vertex_buffer:     ^sdl.GPUBuffer,
	index_buffer:      ^sdl.GPUBuffer,
	texture:           ^sdl.GPUTexture,
	sampler:           ^sdl.GPUSampler,
	window:            ^sdl.Window,
	device:            ^sdl.GPUDevice,
	graphics_pipeline: ^sdl.GPUGraphicsPipeline,
}

PositionColorVertex :: struct {
	position: [3]f32,
	color:    [4]u8,
}

PositionTextureVertex :: struct {
	position: [3]f32,
	uv:       [2]f32,
}

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

load_image :: proc(image_filename: string, desired_channels: int) -> ^sdl.Surface {
	fullpath := fmt.ctprintf("Content/Images/%s", image_filename)
	format: sdl.PixelFormat

	result := sdl.LoadBMP(fullpath)
	if result == nil {
		log.errorf("unable to load image: %s, err: %s", fullpath, sdl.GetError())
		return nil
	}

	if desired_channels == 4 {
		format = .ABGR8888
	} else {
		log.errorf("unexpected desired channels: %s", desired_channels)
		sdl.DestroySurface(result)
		return nil
	}

	if result.format != format {
		next := sdl.ConvertSurface(result, format)
		sdl.DestroySurface(result)
		result = next
	}
	return result
}
