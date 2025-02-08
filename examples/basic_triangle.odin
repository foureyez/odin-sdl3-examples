package examples

import "core:log"
import sdl "vendor:sdl3"

init_basic_triangle :: proc() -> bool {
	if !sdl.Init({.VIDEO}) {
		log.errorf("unable to initialize sdl, error: %s", sdl.GetError())
		return false
	}

	ctx.device = sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, false, nil) // Pass nil for sdl to auto select the correct device type (vulkan, metal, d12) 
	if ctx.device == nil {
		log.errorf("unable to initialize gpu device, error: %s", sdl.GetError())
		return false
	}

	ctx.window = sdl.CreateWindow("sdl demo", 640, 480, {.RESIZABLE})
	if ctx.window == nil {
		log.errorf("unable to initialize window, error: %s", sdl.GetError())
		return false
	}

	if !sdl.ClaimWindowForGPUDevice(ctx.device, ctx.window) {
		log.errorf("unable to claim window for gpu device, error: %s", sdl.GetError())
		return false
	}

	vert_shader := load_shader(ctx.device, "RawTriangle.vert", 0, 0, 0, 0)
	if vert_shader == nil {
		return false
	}

	frag_shader := load_shader(ctx.device, "SolidColor.frag", 0, 0, 0, 0)
	if frag_shader == nil {
		return false
	}

	color_target_descriptions := [1]sdl.GPUColorTargetDescription{{format = sdl.GetGPUSwapchainTextureFormat(ctx.device, ctx.window)}}
	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		target_info = sdl.GPUGraphicsPipelineTargetInfo {
			num_color_targets = u32(len(color_target_descriptions)),
			color_target_descriptions = raw_data(&color_target_descriptions),
		},
		primitive_type = .TRIANGLELIST,
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		rasterizer_state = sdl.GPURasterizerState{fill_mode = .FILL},
	}

	ctx.graphics_pipeline = sdl.CreateGPUGraphicsPipeline(ctx.device, pipeline_create_info)
	if ctx.graphics_pipeline == nil {
		log.errorf("unable to create graphics pipeline, error: %s", sdl.GetError())
		return false
	}

	sdl.ReleaseGPUShader(ctx.device, vert_shader)
	sdl.ReleaseGPUShader(ctx.device, frag_shader)
	return true
}

update_basic_triangle :: proc() {
	is_running := true
	event: sdl.Event

	for is_running {
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				is_running = false
			}
		}

		command_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
		if command_buffer == nil {
			log.errorf("unable to acquire command buffer: %s", sdl.GetError())
			return
		}

		swapchain_texture: ^sdl.GPUTexture
		if sdl.WaitAndAcquireGPUSwapchainTexture(command_buffer, ctx.window, &swapchain_texture, nil, nil) {
			color_target_info := sdl.GPUColorTargetInfo {
				texture     = swapchain_texture,
				clear_color = sdl.FColor{1, 1, 1, 1},
				load_op     = .CLEAR,
				store_op    = .STORE,
			}

			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
			sdl.BindGPUGraphicsPipeline(render_pass, ctx.graphics_pipeline)
			// sdl.SetGPUViewport(render_pass, viewport)
			// sdl.SetGPUScissor(render_pass, scissor_rect)

			sdl.DrawGPUPrimitives(render_pass, 3, 100, 0, 0)
			sdl.EndGPURenderPass(render_pass)
		}

		if !sdl.SubmitGPUCommandBuffer(command_buffer) {
			log.errorf("unable to submit command buffer: %s", sdl.GetError())
			return
		}
	}
}

destroy_basic_triangle :: proc() {
	if ctx.window != nil {
		sdl.DestroyWindow(ctx.window)
	}

	if ctx.graphics_pipeline != nil {
		sdl.ReleaseGPUGraphicsPipeline(ctx.device, ctx.graphics_pipeline)
	}

	if ctx.device != nil {
		sdl.DestroyGPUDevice(ctx.device)
	}
}
