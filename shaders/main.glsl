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
varying vec3 worldPosition;

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

    worldPosition = position + Pos;

    vec3 view = mulVec3Matrix4x4(cameras[0].ViewMatrix, worldPosition).xyz;

    z = view.z;

    vec4 clip = mulVec3Matrix4x4(cameras[0].ProjMatrix, view);

    gl_Position = clip;
}

#endif

float square(float x) {
    return x * x;
}

vec3 mx_ggx_dir_albedo_analytic(float NdotV, float alpha, vec3 F0, vec3 F90) {
    float x = NdotV;
    float y = alpha;
    float x2 = square(x);
    float y2 = square(y);
    vec4 r = vec4(0.1003, 0.9345, 1.0, 1.0) +
        vec4(-0.6303, -2.323, -1.765, 0.2281) * x +
        vec4(9.748, 2.229, 8.263, 15.94) * y +
        vec4(-2.038, -3.748, 11.53, -55.83) * x * y +
        vec4(29.34, 1.424, 28.96, 13.08) * x2 +
        vec4(-8.245, -0.7684, -7.507, 41.26) * y2 +
        vec4(-26.44, 1.436, -36.11, 54.9) * x2 * y +
        vec4(19.99, 0.2913, 15.86, 300.2) * x * y2 +
        vec4(-5.448, 0.6286, 33.37, -285.1) * x2 * y2;
    vec2 AB = clamp(r.xy / r.zw, 0.0, 1.0);
    return F0 * AB.x + F90 * AB.y;
}

// fresnel at 0 degrees for dielectrics
vec3 computeF0(vec3 baseColor, float metallic, float reflectance) {
    float r = 0.16 * reflectance * reflectance;

    return baseColor * metallic + (r * (1.0 - metallic));
}

float pow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

vec3 F_Schlick(const vec3 f0, float f90, float VoH) {
    // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

vec3 fresnel(const vec3 f0, float LoH) {
    float f90 = saturate(dot(f0, vec3(50.0 * 0.33)));
    return F_Schlick(f0, f90, LoH);
}

float perceptualRoughnessToLod(float perceptualRoughness) {
    // The mapping below is a quadratic fit for log2(perceptualRoughness)+iblRoughnessOneLevel when
    // iblRoughnessOneLevel is 4. We found empirically that this mapping works very well for
    // a 256 cubemap with 5 levels used. But also scales well for other iblRoughnessOneLevel values.
    return 9.0 * perceptualRoughness * (2.0 - perceptualRoughness);
}

vec3 prefilteredRadiance(samplerCube env, const vec3 r, float perceptualRoughness) {
    float lod = perceptualRoughnessToLod(perceptualRoughness);
    return textureLod(env, r, lod).rgb;
}

vec3 computeDiffuseColor(const vec3 baseColor, float metallic) {
    return baseColor * (1.0 - metallic);
}

uniform sampler2D DepthTexture;
uniform samplerCube SpecularCubemap;
uniform samplerCube IrradianceCubemap;

#ifdef PIXEL

out vec4 FragColor;
void pixelmain() {
    float viewZ = z;

    float fog = 1.0 - exp(-abs(viewZ) * 0.01);

    vec4 color = texture(voxelTextures, vec3(uv, type));

    vec3 irradiance = textureLod(IrradianceCubemap, normal, 0.0).rgb;

    vec3 viewRay = normalize(worldPosition - cameras[0].Position);
    vec3 reflected = reflect(viewRay, normal);
    if (type == 3.0)
        reflected = refract(viewRay, normal, 1.0 / 1.33);

    reflected.y = -reflected.y;

    float NoV = clampNoV(dot(normal, -viewRay));

    float metallic = 0.0;
    float perceptualRoughness = 0.75;

    if (type == 3.0) {
        metallic = 1.0;
        perceptualRoughness = 0.05;
    }

    vec3 fresnel0 = computeF0(color.rgb, metallic, 0.0);
    float f90 = saturate(dot(fresnel0, vec3(50.0 * 0.33)));
    vec3 E = mx_ggx_dir_albedo_analytic(NoV, perceptualRoughness, fresnel0, vec3(f90));

    vec3 reflectedColor = prefilteredRadiance(SpecularCubemap, reflected, perceptualRoughness);
    vec3 diffuseColor = computeDiffuseColor(color.rgb, metallic);

    irradiance *= diffuseColor * (1.0 - E);
    reflectedColor *= E;

    // water
    if (type == 3.0) {
        float groundDepth = texture(DepthTexture, love_PixelCoord.xy / love_ScreenSize.xy).r;
        float groundZ = getViewZ(groundDepth);

        float distInWater = abs(abs(groundZ) - abs(viewZ));
        float waterTransmittance = exp(-distInWater);

        color.w = 1.0 - waterTransmittance;
    }

    color = vec4(reflectedColor + irradiance, color.w);

    FragColor = vec4(mix(color.xyz, vec3(0.6), fog), color.w);
}

#endif