package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "examples"


main :: proc() {
	type := "texture"
	if len(os.args) > 1 {
		type = os.args[1]
	}

	cl := log.create_console_logger()
	context.logger = cl
	log.infof("Type: %s", type)

	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer reset_tracking_allocator()

	switch type {
	case "basic":
		examples.init_basic_triangle()
		examples.update_basic_triangle()
		examples.destroy_basic_triangle()
	case "buffered":
		examples.init_quad()
		examples.update_quad()
		examples.destroy_quad()
	case "texture":
		examples.init_textured_quad()
		examples.update_textured_quad()
		examples.destroy_textured_quad()
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
