#pragma language glsl4

const int MAX_VOXEL_TYPES = 32;

#include "constants.glsl"
#include "functions.glsl"

uniform sampler2DArray voxelTextures;

uniform highp vec3 Pos;

varying float type;
varying vec2 uv;
varying float z;
varying vec3 normal;

const vec3[6] normals = vec3[6](vec3(0, 0, -1), vec3(0, 0, 1), vec3(-1, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, -1, 0));

#ifdef VERTEX
attribute uvec4 VertexData;
attribute ivec4 VertexTexCoord;

void vertexmain() {
    vec3 position = vec3(VertexData.xyz);
    type = float(VertexData.w);

    if (type == 3.0) {
        position.y += float(VertexTexCoord.z) / 127.0;
    }

    uv = vec2(VertexTexCoord.xy);
    normal = normals[VertexTexCoord.w];

    vec3 view = mulVec3Matrix4x4(cameras[0].ViewMatrix, (position + Pos)).xyz;

    z = view.z;

    vec4 clip = mulVec3Matrix4x4(cameras[0].ProjMatrix, view);

    gl_Position = clip;
}

#endif

uniform sampler2D DepthTexture;

#ifdef PIXEL

out vec4 FragColor;
void pixelmain() {
    float viewZ = z;

    float fog = 1.0 - exp(-abs(viewZ) * 0.01);

    vec4 color = texture(voxelTextures, vec3(uv, type));

    float diffuse = clamp(0.0, dot(normal, normalize(vec3(0.23, 1.0, 0.34))), 1.0) * (1.0 / PI);
    float ambient = 0.2;
    float sunIntensity = 3.0;
    diffuse *= sunIntensity;

    // water
    if (type == 3.0) {
        float groundDepth = texture(DepthTexture, love_PixelCoord.xy / love_ScreenSize.xy).r;
        float groundZ = getViewZ(groundDepth);

        float distInWater = abs(abs(groundZ) - abs(viewZ));
        float waterTransmittance = exp(-distInWater);

        color.w = 1.0 - waterTransmittance;
    }

    color = vec4(color.xyz * (diffuse + ambient), color.w);

    FragColor = vec4(mix(color.xyz, vec3(0.6), fog), color.w);
}

#endif