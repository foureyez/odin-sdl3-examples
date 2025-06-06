package examples

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"

vec3 :: [3]f32
vec2 :: [2]f32

ObjData :: struct {
	positions: []vec3,
	normals:   []vec3,
	uvs:       []vec2,
	faces:     []ObjFaceIndex,
}

ObjFaceIndex :: struct {
	pos:    uint,
	normal: uint,
	uv:     uint,
}

obj_load :: proc(filename: string) -> ObjData {
	data, ok := os.read_entire_file_from_filename(fmt.tprintf("assets/models/%s", filename));assert(ok)
	defer delete(data)

	input_string := string(data)

	positions := make([dynamic]vec3)
	normals := make([dynamic]vec3)
	uvs := make([dynamic]vec2)
	faces := make([dynamic]ObjFaceIndex)

	for line in strings.split_lines_iterator(&input_string) {
		if len(line) == 0 do continue

		switch line[0] {
		case 'v':
			switch line[1] {
			case ' ':
				pos := parse_vec3(line[2:])
				append(&positions, pos)
			case 'n':
				normal := parse_vec3(line[3:])
				append(&normals, normal)
			case 't':
				uv := parse_uv(line[3:])
				append(&uvs, uv)
			}
		case 'f':
			indices := parse_face(line[2:])
			append_elems(&faces, indices[0], indices[1], indices[2])
		}
	}

	return {positions = positions[:], normals = normals[:], uvs = uvs[:], faces = faces[:]}
}

obj_destroy :: proc(obj: ObjData) {
	delete(obj.positions)
	delete(obj.normals)
	delete(obj.uvs)
	delete(obj.faces)
}

extract_separated :: proc(s: ^string, sep: byte) -> string {
	sub, ok := strings.split_by_byte_iterator(s, sep)
	assert(ok)
	return sub
}

parse_f32 :: proc(s: string) -> f32 {
	res, ok := strconv.parse_f32(s)
	assert(ok)
	return res
}

parse_uint :: proc(s: string) -> uint {
	res, ok := strconv.parse_uint(s)
	assert(ok)
	return res
}

parse_vec3 :: proc(s: string) -> vec3 {
	s := s
	x := parse_f32(extract_separated(&s, ' '))
	y := parse_f32(extract_separated(&s, ' '))
	z := parse_f32(extract_separated(&s, ' '))
	return {x, y, z}
}

parse_uv :: proc(s: string) -> vec2 {
	s := s
	u := parse_f32(extract_separated(&s, ' '))
	v := parse_f32(extract_separated(&s, ' '))
	return {u, v}
}

parse_face :: proc(s: string) -> [3]ObjFaceIndex {
	s := s
	return {parse_face_index(extract_separated(&s, ' ')), parse_face_index(extract_separated(&s, ' ')), parse_face_index(extract_separated(&s, ' '))}
}

parse_face_index :: proc(s: string) -> ObjFaceIndex {
	s := s
	return {
		pos = parse_uint(extract_separated(&s, '/')) - 1,
		uv = parse_uint(extract_separated(&s, '/')) - 1,
		normal = parse_uint(extract_separated(&s, '/')) - 1,
	}
}
