#pragma language glsl4

#define SKIP_VIEW_Z 1

#include "constants.glsl"
#include "functions.glsl"

#include "fullscreenPass.glsl"

uniform samplerCube SkyboxTexture;
uniform mediump vec3 SkyboxBrightness;

#ifdef PIXEL
out vec4 FragColor;
void pixelmain() {
    vec2 sampleCoords = VarVertexCoord;
    // if (!flipY)
        // sampleCoords.y = 1.0 - sampleCoords.y;

    vec3 worldPosition = getWorldPosition(sampleCoords, 1.0);

    vec3 albedo = textureLod(SkyboxTexture, worldPosition - cameras[0].Position, 0.0).rgb * SkyboxBrightness;

    FragColor = vec4(albedo, 1.0);
}
#endif