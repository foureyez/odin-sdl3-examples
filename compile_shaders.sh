mkdir -p ./assets/shaders/compiled
glslang ./assets/shaders/triangle.frag.glsl -V -o ./assets/shaders/compiled/triangle.frag.spv
glslang ./assets/shaders/triangle.vert.glsl -V -o ./assets/shaders/compiled/triangle.vert.spv

glslang ./assets/shaders/quad.frag.glsl -V -o ./assets/shaders/compiled/quad.frag.spv
glslang ./assets/shaders/quad.vert.glsl -V -o ./assets/shaders/compiled/quad.vert.spv
