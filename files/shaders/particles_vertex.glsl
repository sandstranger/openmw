#version 120

#define PER_PIXEL_LIGHTING 0

#define PARTICLE

#if @diffuseMap
varying vec2 diffuseMapUV;
#endif

varying float depth;

uniform int colorMode;
centroid varying vec4 lighting;

#include "helpsettings.glsl"

#ifdef LINEAR_LIGHTING
  #include "linear_lighting.glsl"
#else
  #include "lighting.glsl"
#endif

void main(void)
{
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    vec4 viewPos = (gl_ModelViewMatrix * gl_Vertex);
    gl_ClipVertex = viewPos;

#if @radialFog
    depth = length(viewPos.xyz);
#else
    depth = gl_Position.z;
#endif

#if @diffuseMap
    diffuseMapUV = (gl_TextureMatrix[@diffuseMapUV] * gl_MultiTexCoord@diffuseMapUV).xy;
#endif

    vec3 viewNormal = normalize((gl_NormalMatrix * gl_Normal).xyz);
    lighting = doLighting(viewPos.xyz, viewNormal, gl_Color);
}
