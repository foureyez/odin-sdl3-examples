package examples

import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"


ubo_quad :: proc() {
	vert_shader := load_shader(ctx.device, "uboquad.vert", 0, 1, 0, 0)
	assert(vert_shader != nil)

	frag_shader := load_shader(ctx.device, "uboquad.frag", 0, 0, 0, 0)
	assert(frag_shader != nil)

	color_target_descriptions := [1]sdl.GPUColorTargetDescription{{format = sdl.GetGPUSwapchainTextureFormat(ctx.device, ctx.window)}}

	vertex_attributes := [2]sdl.GPUVertexAttribute {
		{location = 0, offset = 0, buffer_slot = 0, format = .FLOAT3},
		{location = 1, offset = size_of([3]f32), buffer_slot = 0, format = .UBYTE4_NORM},
	}

	vertex_buffer_descriptions := [1]sdl.GPUVertexBufferDescription {
		{slot = 0, input_rate = .VERTEX, instance_step_rate = 0, pitch = size_of(PositionColorVertex)},
	}

	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		vertex_input_state = sdl.GPUVertexInputState {
			vertex_attributes = raw_data(&vertex_attributes),
			num_vertex_attributes = len(vertex_attributes),
			vertex_buffer_descriptions = raw_data(&vertex_buffer_descriptions),
			num_vertex_buffers = len(vertex_buffer_descriptions),
		},
		target_info = sdl.GPUGraphicsPipelineTargetInfo {
			color_target_descriptions = raw_data(&color_target_descriptions),
			num_color_targets = u32(len(color_target_descriptions)),
		},
		primitive_type = .TRIANGLELIST,
		rasterizer_state = sdl.GPURasterizerState{fill_mode = .FILL},
	}

	ctx.graphics_pipeline = sdl.CreateGPUGraphicsPipeline(ctx.device, pipeline_create_info)
	assert(ctx.graphics_pipeline != nil, string(sdl.GetError()))

	sdl.ReleaseGPUShader(ctx.device, vert_shader)
	sdl.ReleaseGPUShader(ctx.device, frag_shader)

	vertices := []PositionColorVertex {
		{position = {-0.5, -0.5, 0}, color = {0, 0, 255, 255}},
		{position = {0.5, -0.5, 0}, color = {255, 0, 0, 255}},
		{position = {0.5, 0.5, 0}, color = {255, 0, 0, 255}},
		{position = {-0.5, 0.5, 0}, color = {255, 0, 0, 255}},
	}
	indices := []u16{0, 1, 2, 0, 2, 3}

	vbuffer_size := size_of(PositionColorVertex) * len(vertices)
	ibuffer_size := size_of(u16) * len(indices)

	ctx.vertex_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(vbuffer_size)})
	ctx.index_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = u32(ibuffer_size)})

	tbuffer := sdl.CreateGPUTransferBuffer(ctx.device, sdl.GPUTransferBufferCreateInfo({usage = .UPLOAD, size = u32(vbuffer_size + ibuffer_size)}))
	tbufferptr := sdl.MapGPUTransferBuffer(ctx.device, tbuffer, false)

	mem.copy(tbufferptr, raw_data(vertices), vbuffer_size)
	tbufferoffsetptr := mem.ptr_offset(cast(^u8)tbufferptr, vbuffer_size)
	mem.copy(tbufferoffsetptr, raw_data(indices), ibuffer_size)
	sdl.UnmapGPUTransferBuffer(ctx.device, tbuffer)

	cmd_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
	copy_pass := sdl.BeginGPUCopyPass(cmd_buffer)
	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = tbuffer},
		sdl.GPUBufferRegion{buffer = ctx.vertex_buffer, size = u32(vbuffer_size)},
		false,
	)

	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = tbuffer, offset = u32(vbuffer_size)},
		sdl.GPUBufferRegion{buffer = ctx.index_buffer, offset = 0, size = u32(ibuffer_size)},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)
	if ok := sdl.SubmitGPUCommandBuffer(cmd_buffer); !ok {
		log.errorf("unable to copy the vertex data to gpu: %s", sdl.GetError())
	}

	sdl.ReleaseGPUTransferBuffer(ctx.device, tbuffer)

	sdl.ShowWindow(ctx.window)
	is_running := true
	event: sdl.Event

	UBO :: struct {
		mvp: matrix[4, 4]f32,
	}

	window_size: [2]i32
	sdl.GetWindowSize(ctx.window, &window_size.x, &window_size.y)

	ROTATION_SPEED :: 90
	rotation: f32 = 0
	ubo := UBO{}
	aspect_ratio := f32(window_size.x) / f32(window_size.y)
	fov := linalg.to_radians(f32(70))
	proj_mat := linalg.matrix4_perspective_f32(fov, aspect_ratio, 0.00001, 10000)

	last_tick := sdl.GetTicks()
	for is_running {
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				is_running = false
			case .WINDOW_RESIZED:
				// Recalculate aspect ratio and projection matrix
				sdl.GetWindowSize(ctx.window, &window_size.x, &window_size.y)
				aspect_ratio = f32(window_size.x) / f32(window_size.y)
				log.info(aspect_ratio)
				proj_mat = linalg.matrix4_perspective_f32(fov, aspect_ratio, 0.00001, 10000)
			}
		}

		curr_tick := sdl.GetTicks()
		delta_time_ms := f32(curr_tick - last_tick)
		last_tick = curr_tick

		cmd_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
		if cmd_buffer == nil {
			log.errorf("unable to acquire command buffer: %s", sdl.GetError())
			return
		}

		rotation += ROTATION_SPEED * delta_time_ms / 1000.0
		model_mat := linalg.matrix4_translate_f32({0, 0, -5}) * linalg.matrix4_rotate_f32(linalg.to_radians(rotation), {0, 1, 0})
		ubo.mvp = proj_mat * model_mat

		swapchain_tex: ^sdl.GPUTexture
		if sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buffer, ctx.window, &swapchain_tex, nil, nil) {
			color_target_info := sdl.GPUColorTargetInfo {
				texture     = swapchain_tex,
				load_op     = .CLEAR,
				store_op    = .STORE,
				clear_color = sdl.FColor{1, 1, 1, 1},
			}
			render_pass := sdl.BeginGPURenderPass(cmd_buffer, &color_target_info, 1, nil)
			sdl.BindGPUGraphicsPipeline(render_pass, ctx.graphics_pipeline)
			sdl.PushGPUVertexUniformData(cmd_buffer, 0, &ubo, size_of(ubo))

			vertex_bindings := []sdl.GPUBufferBinding{{buffer = ctx.vertex_buffer}}
			sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(vertex_bindings), u32(len(vertex_bindings)))
			sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = ctx.index_buffer}, ._16BIT)
			sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)
			sdl.EndGPURenderPass(render_pass)
		}

		if !sdl.SubmitGPUCommandBuffer(cmd_buffer) {
			log.errorf("unable to submit command buffer: %s", sdl.GetError())
		}
	}
}

destroy_ubo_quad :: proc() {
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
