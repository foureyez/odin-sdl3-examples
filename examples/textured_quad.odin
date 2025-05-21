package examples

import "core:log"
import "core:mem"
import sdl "vendor:sdl3"

init_textured_quad :: proc(window: ^sdl.Window, device: ^sdl.GPUDevice) -> bool {
	ctx.window = window
	ctx.device = device
	vert_shader := load_shader(ctx.device, "TexturedQuad.vert", 0, 0, 0, 0)
	if vert_shader == nil {
		return false
	}

	frag_shader := load_shader(ctx.device, "TexturedQuad.frag", 1, 0, 0, 0)
	if frag_shader == nil {
		return false
	}

	// Load the image
	image_data := load_image("ravioli.bmp", 4)
	if (image_data == nil) {
		return false
	}

	color_target_descriptions := [1]sdl.GPUColorTargetDescription{{format = sdl.GetGPUSwapchainTextureFormat(ctx.device, ctx.window)}}

	vertex_attributes := [2]sdl.GPUVertexAttribute {
		{location = 0, offset = 0, buffer_slot = 0, format = .FLOAT3},
		{location = 1, offset = size_of([3]f32), buffer_slot = 0, format = .FLOAT2},
	}

	vertex_buffer_descriptions := [1]sdl.GPUVertexBufferDescription {
		{slot = 0, input_rate = .VERTEX, instance_step_rate = 0, pitch = size_of(PositionTextureVertex)},
	}

	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_input_state = sdl.GPUVertexInputState {
			num_vertex_attributes = u32(len(vertex_attributes)),
			vertex_attributes = raw_data(&vertex_attributes),
			num_vertex_buffers = u32(len(vertex_buffer_descriptions)),
			vertex_buffer_descriptions = raw_data(&vertex_buffer_descriptions),
		},
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

	ctx.sampler = sdl.CreateGPUSampler(
		ctx.device,
		sdl.GPUSamplerCreateInfo {
			min_filter = .NEAREST,
			mag_filter = .NEAREST,
			mipmap_mode = .NEAREST,
			address_mode_u = .REPEAT,
			address_mode_v = .REPEAT,
			address_mode_w = .REPEAT,
		},
	)

	vertices := []PositionTextureVertex {
		{position = {-0.5, 0.5, 0}, uv = {0, 0}},
		{position = {0.5, 0.5, 0}, uv = {1, 0}},
		{position = {0.5, -0.5, 0}, uv = {1, 1}},
		{position = {-0.5, -0.5, 0}, uv = {0, 1}},
	}
	indices := []u16{0, 1, 2, 0, 2, 3}

	vbuffer_size := size_of(PositionTextureVertex) * len(vertices)
	ibuffer_size := size_of(u16) * len(indices)
	tex_size: int = int(image_data.w) * int(image_data.h) * 4
	ctx.vertex_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(vbuffer_size)})
	sdl.SetGPUBufferName(ctx.device, ctx.vertex_buffer, "VertexBuffer")
	ctx.index_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = u32(ibuffer_size)})
	sdl.SetGPUBufferName(ctx.device, ctx.index_buffer, "IndexBuffer")
	ctx.texture = sdl.CreateGPUTexture(
		ctx.device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			format = .R8G8B8A8_UNORM,
			width = u32(image_data.w),
			height = u32(image_data.h),
			layer_count_or_depth = 1,
			num_levels = 1,
			usage = {.SAMPLER},
		},
	)
	sdl.SetGPUTextureName(ctx.device, ctx.texture, "RavioliTex")


	buffer_transfer_buffer := sdl.CreateGPUTransferBuffer(
		ctx.device,
		sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(vbuffer_size + ibuffer_size)},
	)
	texture_transfer_buffer := sdl.CreateGPUTransferBuffer(ctx.device, sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(tex_size)})
	defer sdl.ReleaseGPUTransferBuffer(ctx.device, buffer_transfer_buffer)
	defer sdl.ReleaseGPUTransferBuffer(ctx.device, texture_transfer_buffer)

	buffer_transfer_ptr := sdl.MapGPUTransferBuffer(ctx.device, buffer_transfer_buffer, false) // Get mapped pointer to the transfer buffer
	mem.copy(buffer_transfer_ptr, raw_data(vertices), vbuffer_size) // Copy vertices to transfer buffer using the mapped pointer
	index_buffer_transfer_ptr := mem.ptr_offset(cast(^u8)buffer_transfer_ptr, vbuffer_size) // Offset the mapped pointer by size of vertex buffer size
	mem.copy(index_buffer_transfer_ptr, raw_data(indices), ibuffer_size) // Copy indices to transfer buffer using the mapped pointer

	sdl.UnmapGPUTransferBuffer(ctx.device, buffer_transfer_buffer) // Unmap transfer bufffer

	texture_transfer_ptr := sdl.MapGPUTransferBuffer(ctx.device, texture_transfer_buffer, false) // Get mapped pointer to the transfer buffer
	mem.copy(texture_transfer_ptr, image_data.pixels, tex_size)

	//Upload data from transfer buffer to vertex buffer
	upload_command_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
	copy_pass := sdl.BeginGPUCopyPass(upload_command_buffer)
	// Copy vertex info
	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = buffer_transfer_buffer},
		sdl.GPUBufferRegion{buffer = ctx.vertex_buffer, size = u32(vbuffer_size)},
		false,
	)

	// Copy index info
	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = buffer_transfer_buffer, offset = u32(vbuffer_size)},
		sdl.GPUBufferRegion{buffer = ctx.index_buffer, size = u32(ibuffer_size)},
		false,
	)

	// Copy texture
	sdl.UploadToGPUTexture(
		copy_pass,
		sdl.GPUTextureTransferInfo{transfer_buffer = texture_transfer_buffer},
		sdl.GPUTextureRegion{texture = ctx.texture, w = u32(image_data.w), h = u32(image_data.h), d = 1},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	if !sdl.SubmitGPUCommandBuffer(upload_command_buffer) {
		log.errorf("unable to copy from transfer to vertex buffer, err: %s", sdl.GetError())
		return false
	}
	sdl.DestroySurface(image_data)
	sdl.ShowWindow(ctx.window)
	return true
}


update_textured_quad :: proc() {
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
				clear_color = sdl.FColor{0.2, 0.2, 0.2, 1},
				load_op     = .CLEAR,
				store_op    = .STORE,
			}

			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, nil)
			sdl.BindGPUGraphicsPipeline(render_pass, ctx.graphics_pipeline)
			// sdl.SetGPUViewport(render_pass, viewport)
			// sdl.SetGPUScissor(render_pass, scissor_rect)

			vertex_bindings := []sdl.GPUBufferBinding{{buffer = ctx.vertex_buffer}}
			sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(vertex_bindings), u32(len(vertex_bindings)))
			sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = ctx.index_buffer}, ._16BIT)
			sampler_bindings := []sdl.GPUTextureSamplerBinding{{texture = ctx.texture, sampler = ctx.sampler}}
			sdl.BindGPUFragmentSamplers(render_pass, 0, raw_data(sampler_bindings), u32(len(sampler_bindings)))

			sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
			sdl.EndGPURenderPass(render_pass)
		}

		if !sdl.SubmitGPUCommandBuffer(command_buffer) {
			log.errorf("unable to submit command buffer: %s", sdl.GetError())
			return
		}
	}
}

destroy_textured_quad :: proc() {
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
