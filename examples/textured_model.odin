package examples

import "core:log"
import "core:math/linalg"
import "core:mem"
import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

textured_model :: proc() {
	vert_shader := load_shader(ctx.device, "model.vert", 0, 1, 0, 0)
	assert(vert_shader != nil)

	frag_shader := load_shader(ctx.device, "model.frag", 1, 0, 0, 0)
	assert(frag_shader != nil)

	model_data := obj_load("taxi.obj")
	log.info(sdl.GPUTextureSupportsFormat(ctx.device, .D24_UNORM, .D2, {.DEPTH_STENCIL_TARGET}))

	img_size: [2]i32
	// stbi.set_flip_vertically_on_load(1)
	pixels := stbi.load("assets/textures/colormap.png", &img_size.x, &img_size.y, nil, 4);assert(pixels != nil)
	pixels_byte_size := img_size.x * img_size.y * 4

	vertices := make([]PositionTextureVertex, len(model_data.faces))
	indices := make([]u16, len(model_data.faces))

	for face, i in model_data.faces {
		uv := model_data.uvs[face.uv]
		vertices[i] = {
			position = model_data.positions[face.pos],
			uv       = {uv.x, 1 - uv.y},
		}
		indices[i] = u16(i)
	}

	window_size: [2]i32
	sdl.GetWindowSize(ctx.window, &window_size.x, &window_size.y)

	color_target_descriptions := [1]sdl.GPUColorTargetDescription{{format = sdl.GetGPUSwapchainTextureFormat(ctx.device, ctx.window)}}
	DEPTH_TEXTURE_FORMAT :: sdl.GPUTextureFormat.D24_UNORM

	vertex_attributes := [2]sdl.GPUVertexAttribute {
		{location = 0, offset = 0, buffer_slot = 0, format = .FLOAT3},
		{location = 1, offset = size_of([3]f32), buffer_slot = 0, format = .FLOAT2},
	}

	vertex_buffer_descriptions := [1]sdl.GPUVertexBufferDescription {
		{slot = 0, input_rate = .VERTEX, instance_step_rate = 0, pitch = size_of(PositionTextureVertex)},
	}


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

	vbuffer_size := size_of(PositionTextureVertex) * len(vertices)
	ctx.vertex_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(vbuffer_size)})
	sdl.SetGPUBufferName(ctx.device, ctx.vertex_buffer, "VertexBuffer")

	ibuffer_size := size_of(u16) * len(indices)
	ctx.index_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = u32(ibuffer_size)})
	sdl.SetGPUBufferName(ctx.device, ctx.index_buffer, "IndexBuffer")

	tex_size: int = int(img_size.x) * int(img_size.y) * 4
	ctx.texture = sdl.CreateGPUTexture(
		ctx.device,
		sdl.GPUTextureCreateInfo {
			type = .D2,
			format = .R8G8B8A8_UNORM,
			width = u32(img_size.x),
			height = u32(img_size.y),
			layer_count_or_depth = 1,
			num_levels = 1,
			usage = {.SAMPLER},
		},
	)
	sdl.SetGPUTextureName(ctx.device, ctx.texture, "colorspace")

	ctx.depth_texture = sdl.CreateGPUTexture(
		ctx.device,
		sdl.GPUTextureCreateInfo {
			format = DEPTH_TEXTURE_FORMAT,
			usage = {.DEPTH_STENCIL_TARGET},
			width = u32(window_size.x),
			height = u32(window_size.y),
			layer_count_or_depth = 1,
			num_levels = 1,
		},
	)

	buffer_transfer_buffer := sdl.CreateGPUTransferBuffer(
		ctx.device,
		sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(vbuffer_size + ibuffer_size)},
	)

	// Copy vertices to transfer buffer
	buffer_transfer_ptr := sdl.MapGPUTransferBuffer(ctx.device, buffer_transfer_buffer, false) // Get mapped pointer to the transfer buffer
	mem.copy(buffer_transfer_ptr, raw_data(vertices), vbuffer_size)

	// Copy indices to transfer buffer
	index_buffer_transfer_ptr := mem.ptr_offset(cast(^u8)buffer_transfer_ptr, vbuffer_size) // Offset the mapped pointer by size of vertex buffer size
	mem.copy(index_buffer_transfer_ptr, raw_data(indices), ibuffer_size)

	sdl.UnmapGPUTransferBuffer(ctx.device, buffer_transfer_buffer) // Unmap transfer bufffer

	// Copy image to texture transfer buffer
	texture_transfer_buffer := sdl.CreateGPUTransferBuffer(ctx.device, sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(tex_size)})
	texture_transfer_ptr := sdl.MapGPUTransferBuffer(ctx.device, texture_transfer_buffer, false) // Get mapped pointer to the transfer buffer
	mem.copy(texture_transfer_ptr, pixels, tex_size)


	// Upload the data from transfer buffers to the gpu buffers 
	upload_command_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
	copy_pass := sdl.BeginGPUCopyPass(upload_command_buffer)

	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = buffer_transfer_buffer},
		sdl.GPUBufferRegion{buffer = ctx.vertex_buffer, size = u32(vbuffer_size)},
		false,
	)

	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = buffer_transfer_buffer, offset = u32(vbuffer_size)},
		sdl.GPUBufferRegion{buffer = ctx.index_buffer, size = u32(ibuffer_size)},
		false,
	)

	sdl.UploadToGPUTexture(
		copy_pass,
		sdl.GPUTextureTransferInfo{transfer_buffer = texture_transfer_buffer},
		sdl.GPUTextureRegion{texture = ctx.texture, w = u32(img_size.x), h = u32(img_size.y), d = 1},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	if !sdl.SubmitGPUCommandBuffer(upload_command_buffer) {
		log.errorf("unable to copy from transfer to vertex buffer, err: %s", sdl.GetError())
		return
	}

	obj_destroy(model_data)
	sdl.ShowWindow(ctx.window)

	sdl.ReleaseGPUTransferBuffer(ctx.device, buffer_transfer_buffer)
	sdl.ReleaseGPUTransferBuffer(ctx.device, texture_transfer_buffer)

	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_input_state = sdl.GPUVertexInputState {
			num_vertex_attributes = u32(len(vertex_attributes)),
			vertex_attributes = raw_data(&vertex_attributes),
			num_vertex_buffers = u32(len(vertex_buffer_descriptions)),
			vertex_buffer_descriptions = raw_data(&vertex_buffer_descriptions),
		},
		depth_stencil_state = sdl.GPUDepthStencilState{enable_depth_test = true, enable_depth_write = true, compare_op = .LESS_OR_EQUAL},
		target_info = sdl.GPUGraphicsPipelineTargetInfo {
			num_color_targets = u32(len(color_target_descriptions)),
			color_target_descriptions = raw_data(&color_target_descriptions),
			has_depth_stencil_target = true,
			depth_stencil_format = DEPTH_TEXTURE_FORMAT,
		},
		primitive_type = .TRIANGLELIST,
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		rasterizer_state = sdl.GPURasterizerState{fill_mode = .FILL},
	}

	ctx.graphics_pipeline = sdl.CreateGPUGraphicsPipeline(ctx.device, pipeline_create_info)
	if ctx.graphics_pipeline == nil {
		log.errorf("unable to create graphics pipeline, error: %s", sdl.GetError())
		return
	}

	sdl.ReleaseGPUShader(ctx.device, vert_shader)
	sdl.ReleaseGPUShader(ctx.device, frag_shader)

	UBO :: struct {
		mvp: matrix[4, 4]f32,
	}


	ROTATION_SPEED :: 90
	rotation: f32 = 0
	ubo := UBO{}
	aspect_ratio := f32(window_size.x) / f32(window_size.y)
	fov := linalg.to_radians(f32(70))
	proj_mat := linalg.matrix4_perspective_f32(fov, aspect_ratio, 0.001, 10000)

	is_running := true
	event: sdl.Event

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
				proj_mat = linalg.matrix4_perspective_f32(fov, aspect_ratio, 0.001, 10000)
				ctx.depth_texture = sdl.CreateGPUTexture(
					ctx.device,
					sdl.GPUTextureCreateInfo {
						format = DEPTH_TEXTURE_FORMAT,
						usage = {.DEPTH_STENCIL_TARGET},
						width = u32(window_size.x),
						height = u32(window_size.y),
						layer_count_or_depth = 1,
						num_levels = 1,
					},
				)
			}
		}

		curr_tick := sdl.GetTicks()
		delta_time_ms := f32(curr_tick - last_tick)
		last_tick = curr_tick

		command_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
		if command_buffer == nil {
			log.errorf("unable to acquire command buffer: %s", sdl.GetError())
			return
		}

		rotation += ROTATION_SPEED * delta_time_ms / 1000.0
		model_mat := linalg.matrix4_translate_f32({0, 0, -5}) * linalg.matrix4_rotate_f32(linalg.to_radians(rotation), {0, 1, 0})
		ubo.mvp = proj_mat * model_mat

		swapchain_texture: ^sdl.GPUTexture
		if sdl.WaitAndAcquireGPUSwapchainTexture(command_buffer, ctx.window, &swapchain_texture, nil, nil) {
			color_target_info := sdl.GPUColorTargetInfo {
				texture     = swapchain_texture,
				clear_color = sdl.FColor{0.2, 0.2, 0.2, 1},
				load_op     = .CLEAR,
				store_op    = .STORE,
			}

			depth_target_info := sdl.GPUDepthStencilTargetInfo {
				texture     = ctx.depth_texture,
				load_op     = .CLEAR,
				store_op    = .DONT_CARE,
				clear_depth = 1,
			}

			render_pass := sdl.BeginGPURenderPass(command_buffer, &color_target_info, 1, &depth_target_info)
			sdl.BindGPUGraphicsPipeline(render_pass, ctx.graphics_pipeline)
			sdl.PushGPUVertexUniformData(command_buffer, 0, &ubo, size_of(ubo))
			// sdl.SetGPUViewport(render_pass, viewport)
			// sdl.SetGPUScissor(render_pass, scissor_rect)

			vertex_bindings := []sdl.GPUBufferBinding{{buffer = ctx.vertex_buffer}}
			sdl.BindGPUVertexBuffers(render_pass, 0, raw_data(vertex_bindings), u32(len(vertex_bindings)))
			sdl.BindGPUIndexBuffer(render_pass, sdl.GPUBufferBinding{buffer = ctx.index_buffer}, ._16BIT)
			sampler_bindings := []sdl.GPUTextureSamplerBinding{{texture = ctx.texture, sampler = ctx.sampler}}
			sdl.BindGPUFragmentSamplers(render_pass, 0, raw_data(sampler_bindings), u32(len(sampler_bindings)))

			sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)
			sdl.EndGPURenderPass(render_pass)
		}

		if !sdl.SubmitGPUCommandBuffer(command_buffer) {
			log.errorf("unable to submit command buffer: %s", sdl.GetError())
			return
		}
	}
}

destroy_textured_model :: proc() {
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
