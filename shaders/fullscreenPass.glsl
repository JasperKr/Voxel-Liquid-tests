varying vec2 VarVertexCoord;
uniform bool flipY;
#ifdef VERTEX
void vertexmain() {
    VarVertexCoord = vec2((love_VertexID << 1) & 2, love_VertexID & 2);

    vec4 VarScreenPosition = vec4(VarVertexCoord.xy * vec2(2.0, -2.0) + vec2(-1.0, 1.0), 0, 1);

    // OpenGL Flip
    if (!flipY)
        VarVertexCoord.y = 1.0 - VarVertexCoord.y;

    gl_Position = VarScreenPosition;
}
#endif