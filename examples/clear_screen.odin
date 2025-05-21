package examples

import "core:log"
import sdl "vendor:sdl3"

clear_screen :: proc() {
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
				clear_color = sdl.FColor{1, 0.5, 0.5, 1},
				load_op     = .CLEAR,
				store_op    = .STORE,
			}

			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
			sdl.EndGPURenderPass(render_pass)
		}

		if !sdl.SubmitGPUCommandBuffer(command_buffer) {
			log.errorf("unable to submit command buffer: %s", sdl.GetError())
			return
		}
	}
}

destroy_clear_screen :: proc() {
	if ctx.window != nil {
		sdl.DestroyWindow(ctx.window)
	}

	if ctx.device != nil {
		sdl.DestroyGPUDevice(ctx.device)
	}
}
