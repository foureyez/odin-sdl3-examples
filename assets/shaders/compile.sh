# Requires shadercross CLI installed from SDL_shadercross
for filename in *.vert.glsl; do
    if [ -f "$filename" ]; then
        glslang "$filename" -V -o "compiled/${filename/.glsl/.spv}"
        shadercross "compiled/${filename/.glsl/.spv}" -s SPIRV -d MSL -o "compiled/${filename/.glsl/.msl}"
        # shadercross "$filename" -o "compiled/DXIL/${filename/.hlsl/.dxil}"
    fi
done

for filename in *.frag.glsl; do
    if [ -f "$filename" ]; then
        glslang "$filename" -V -o "compiled/${filename/.glsl/.spv}"
        shadercross "compiled/${filename/.glsl/.spv}" -s SPIRV -d MSL -o "compiled/${filename/.glsl/.msl}"
        # shadercross "$filename" -o "compiled/DXIL/${filename/.hlsl/.dxil}"
    fi
done

# for filename in *.comp.hlsl; do
#     if [ -f "$filename" ]; then
#         shadercross "$filename" -o "../Compiled/SPIRV/${filename/.hlsl/.spv}"
#         shadercross "$filename" -o "../Compiled/DXIL/${filename/.hlsl/.dxil}"
#     fi
# done
