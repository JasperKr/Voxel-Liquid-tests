#pragma language glsl4

const int MAX_VOXEL_TYPES = 32;

#include "constants.glsl"
#include "functions.glsl"

uniform sampler2DArray voxelTextures;

uniform highp vec3 Pos;

varying float type;
varying vec3 uv;
varying float z;

#ifdef VERTEX
attribute uvec4 VertexData;
attribute vec3 VertexTexCoord;

void vertexmain() {
    vec3 position = vec3(VertexData.xyz);
    type = float(VertexData.w);

    if (type == 3.0) {
        position.y += VertexTexCoord.z - 1.0;
    }

    uv = VertexTexCoord;

    vec3 view = mulVec3Matrix4x4(cameras[0].ViewMatrix, (position + Pos)).xyz;

    z = view.z;

    gl_Position = mulVec3Matrix4x4(cameras[0].ProjMatrix, view);
}

#endif

#ifdef PIXEL

out vec4 FragColor;
void pixelmain() {
    float fog = 1.0 - exp(-abs(z) * 0.01);

    vec4 color = texture(voxelTextures, vec3(uv.xy, type));

    FragColor = vec4(mix(color.xyz, vec3(0.6), fog), color.w);
}

#endif