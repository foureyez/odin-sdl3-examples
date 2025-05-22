mkdir -p ./assets/shaders/compiled
glslang ./assets/shaders/triangle.frag.glsl -V -o ./assets/shaders/compiled/triangle.frag.spv
glslang ./assets/shaders/triangle.vert.glsl -V -o ./assets/shaders/compiled/triangle.vert.spv
shadercross ./assets/shaders/compiled/triangle.vert.spv -s SPIRV -d MSL -o ./assets/shaders/compiled/triangle.vert.msl
shadercross ./assets/shaders/compiled/triangle.frag.spv -s SPIRV -d MSL -o ./assets/shaders/compiled/triangle.frag.msl

glslang ./assets/shaders/quad.frag.glsl -V -o ./assets/shaders/compiled/quad.frag.spv
glslang ./assets/shaders/quad.vert.glsl -V -o ./assets/shaders/compiled/quad.vert.spv
shadercross ./assets/shaders/compiled/quad.vert.spv -s SPIRV -d MSL -o ./assets/shaders/compiled/quad.vert.msl
shadercross ./assets/shaders/compiled/quad.frag.spv -s SPIRV -d MSL -o ./assets/shaders/compiled/quad.frag.msl

glslang ./assets/shaders/texturedquad.frag.glsl -V -o ./assets/shaders/compiled/texturedquad.frag.spv
glslang ./assets/shaders/texturedquad.vert.glsl -V -o ./assets/shaders/compiled/texturedquad.vert.spv
shadercross ./assets/shaders/compiled/texturedquad.vert.spv -s SPIRV -d MSL -o ./assets/shaders/compiled/texturedquad.vert.msl
shadercross ./assets/shaders/compiled/texturedquad.frag.spv -s SPIRV -d MSL -o ./assets/shaders/compiled/texturedquad.frag.msl
