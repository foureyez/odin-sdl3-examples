package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "examples"
import sdl "vendor:sdl3"

Example :: enum {
	Clear,
	Triangle,
	Quad,
	TexturedQuad,
	BatchedQuad,
}

main :: proc() {
	cl := log.create_console_logger()
	context.logger = cl

	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer reset_tracking_allocator()

	if !sdl.Init({.VIDEO}) {
		log.fatalf("unable to initialize sdl, error: %s", sdl.GetError())
	}

	device := sdl.CreateGPUDevice({.SPIRV, .DXIL, .MSL}, false, nil) // Pass nil for sdl to auto select the correct device type (vulkan, metal, d12) 
	if device == nil {
		log.fatalf("unable to initialize gpu device, error: %s", sdl.GetError())
	}

	window := sdl.CreateWindow("sdl demo", 0, 0, {.RESIZABLE, .MAXIMIZED})
	if window == nil {
		log.fatalf("unable to initialize window, error: %s", sdl.GetError())
	}

	if !sdl.ClaimWindowForGPUDevice(device, window) {
		log.fatalf("unable to claim window for gpu device, error: %s", sdl.GetError())
	}

	examples.init(window, device)
	example_type := Example.TexturedQuad

	switch example_type {
	case .Clear:
		examples.clear_screen()
		examples.destroy_clear_screen()
	case .Triangle:
		examples.basic_triangle()
		examples.destroy_basic_triangle()
	case .Quad:
		examples.quad()
		examples.destroy_quad()
	case .TexturedQuad:
		examples.textured_quad()
		examples.destroy_textured_quad()
	case .BatchedQuad:
		examples.batched_quad()
		examples.destroy_batched_quad()
	}
}


reset_tracking_allocator :: proc() -> bool {
	a := cast(^mem.Tracking_Allocator)context.allocator.data
	err := false
	if len(a.allocation_map) > 0 {
		log.warnf("Leaked allocation count: %v", len(a.allocation_map))
	}
	for _, v in a.allocation_map {
		log.warnf("%v: Leaked %v bytes", v.location, v.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}
