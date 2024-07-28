#pragma language glsl4

uniform sampler2D DepthTexture;

#include "fullscreenPass.glsl"

#ifdef PIXEL
void pixelmain() {
    gl_FragDepth = textureLod(DepthTexture, VarVertexCoord, 0.0).r;
}
#endif