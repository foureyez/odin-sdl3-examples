package texture

import "../common"
import "core:log"
import "core:mem"
import sdl "vendor:sdl3"

ctx: SDLContext
viewport := sdl.GPUViewport{0, 0, 640, 480, 0.1, 1.0}
scissor_rect := sdl.Rect{320, 240, 320, 240}

SDLContext :: struct {
	vertex_buffer:     ^sdl.GPUBuffer,
	index_buffer:      ^sdl.GPUBuffer,
	window:            ^sdl.Window,
	device:            ^sdl.GPUDevice,
	graphics_pipeline: ^sdl.GPUGraphicsPipeline,
}

Vertex :: struct {
	position: [3]f32,
	color:    [4]u8,
}

init :: proc() -> bool {
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

	if !create_graphics_pipeline() {
		log.errorf("unable to create graphics pipeline")
		return false
	}
	return create_buffers()
}

create_buffers :: proc() -> bool {
	vertices := []Vertex {
		{position = {-0.5, -0.5, 0}, color = {0, 0, 255, 255}},
		{position = {0.5, -0.5, 0}, color = {255, 0, 0, 255}},
		{position = {0.5, 0.5, 0}, color = {255, 0, 0, 255}},
		{position = {-0.5, 0.5, 0}, color = {255, 0, 0, 255}},
	}
	indices := []u16{0, 1, 2, 0, 2, 3}

	vbuffer_size := size_of(Vertex) * len(vertices)
	ibuffer_size := size_of(u16) * len(indices)

	ctx.vertex_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = u32(vbuffer_size)})
	sdl.SetGPUBufferName(ctx.device, ctx.vertex_buffer, "VertexBuffer")
	ctx.index_buffer = sdl.CreateGPUBuffer(ctx.device, sdl.GPUBufferCreateInfo{usage = {.INDEX}, size = u32(ibuffer_size)})
	sdl.SetGPUBufferName(ctx.device, ctx.index_buffer, "IndexBuffer")

	transfer_buffer := sdl.CreateGPUTransferBuffer(
		ctx.device,
		sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(vbuffer_size + ibuffer_size)},
	)
	defer sdl.ReleaseGPUTransferBuffer(ctx.device, transfer_buffer)

	transfer_buffer_ptr := sdl.MapGPUTransferBuffer(ctx.device, transfer_buffer, false) // Get mapped pointer to the transfer buffer
	mem.copy(transfer_buffer_ptr, raw_data(vertices), vbuffer_size) // Copy vertices to transfer buffer using the mapped pointer
	index_transfer_buffer_ptr := mem.ptr_offset(cast(^u8)transfer_buffer_ptr, vbuffer_size) // Offset the mapped pointer by size of vertex buffer size
	mem.copy(index_transfer_buffer_ptr, raw_data(indices), ibuffer_size) // Copy indices to transfer buffer using the mapped pointer

	sdl.UnmapGPUTransferBuffer(ctx.device, transfer_buffer) // Unmap transfer bufffer

	//Upload data from transfer buffer to vertex buffer
	upload_command_buffer := sdl.AcquireGPUCommandBuffer(ctx.device)
	copy_pass := sdl.BeginGPUCopyPass(upload_command_buffer)
	// Copy vertex info
	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = transfer_buffer},
		sdl.GPUBufferRegion{buffer = ctx.vertex_buffer, size = u32(vbuffer_size)},
		false,
	)

	// Copy index info
	sdl.UploadToGPUBuffer(
		copy_pass,
		sdl.GPUTransferBufferLocation{transfer_buffer = transfer_buffer, offset = u32(vbuffer_size)},
		sdl.GPUBufferRegion{buffer = ctx.index_buffer, size = u32(ibuffer_size)},
		false,
	)

	sdl.EndGPUCopyPass(copy_pass)
	if !sdl.SubmitGPUCommandBuffer(upload_command_buffer) {
		log.errorf("unable to copy from transfer to vertex buffer, err: %s", sdl.GetError())
		return false
	}

	return true
}

create_graphics_pipeline :: proc() -> bool {
	vert_shader := common.load_shader(ctx.device, "PositionColor.vert", 0, 0, 0, 0)
	if vert_shader == nil {
		return false
	}

	frag_shader := common.load_shader(ctx.device, "SolidColor.frag", 0, 0, 0, 0)
	if frag_shader == nil {
		return false
	}

	color_target_descriptions := [1]sdl.GPUColorTargetDescription{{format = sdl.GetGPUSwapchainTextureFormat(ctx.device, ctx.window)}}

	vertex_attributes := [2]sdl.GPUVertexAttribute {
		{location = 0, offset = 0, buffer_slot = 0, format = .FLOAT3},
		{location = 1, offset = size_of([3]f32), buffer_slot = 0, format = .UBYTE4_NORM},
	}

	vertex_buffer_descriptions := [1]sdl.GPUVertexBufferDescription {
		{slot = 0, input_rate = .VERTEX, instance_step_rate = 0, pitch = size_of(Vertex)},
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


	sdl.ShowWindow(ctx.window)
	return true
}

update :: proc() {
	is_running := true
	event: sdl.Event

	for is_running {
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				is_running = false
			}
		}
		draw()
	}
}

draw :: proc() {
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

		sdl.DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0)
		sdl.EndGPURenderPass(render_pass)
	}

	if !sdl.SubmitGPUCommandBuffer(command_buffer) {
		log.errorf("unable to submit command buffer: %s", sdl.GetError())
		return
	}
}

destroy :: proc() {
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
