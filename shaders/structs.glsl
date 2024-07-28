struct Ray {
    vec3 origin;
    vec3 direction;
};

struct DirectionalLight {
    vec4 position;
    vec4 colorData;
    vec3 direction;
    mat4 matrix;
    int shadowMapIndex;
};

struct PointLight {
    vec4 position;
    vec4 colorData;
};

struct SpotLight {
    vec3 position;
    vec4 colorData;
    vec4 direction;
    mat4 matrix;
    int shadowMapIndex;
};

struct AreaLight {
    vec3 position;
    vec4 colorData;
    vec2 halfSize;
    vec3 up;
    vec3 right;
    vec3 front;
    ivec2 dummy;
};

struct SphereLight {
    vec4 position;
    vec4 colorData;
};

struct Pixel {
    vec3 normal;
    vec3 albedo;
    vec3 diffuse;
    float perceptualRoughness;
    float roughness;
    float metallic;
    vec3 f0;
    vec3 dfg;
    vec3 energyCompensation;
};

struct Material {
    vec3 diffuse;
    float perceptualRoughness;
    float metallic;
    float occlusion;
    vec3 emissive;
    float reflectance;
};

struct FogData {
    vec3 fogColor;
    float fogCutOffDistance;
    vec3 fogDensity;
    float fogHeightFalloff;
    float iblLuminance;
    float fogMaxOpacity;
    float fogStart;
    float fogInscatteringSize;
    float fogInscatteringStart;
    vec4 lightColorIntensity;
    vec3 lightDirection;
    float samplesPerMeter;
    float maxSamples;
};

#ifndef SKIP_DEFINE_CAMERA

struct Camera {
    highp mat4 ViewProjectionMatrix;
    highp mat4 InverseViewProjectionMatrix;
    highp mat4 ViewMatrix;
    highp mat4 InverseViewMatrix;
    highp mat4 ProjMatrix;
    highp mat4 InverseProjectionMatrix;
    highp vec3 Position;
    highp float Near;
    highp float Far;
    highp float NearMulFar;
    highp float FarMinusNear;
};

readonly buffer CameraBuffer {
    Camera cameras[];
};

#endif