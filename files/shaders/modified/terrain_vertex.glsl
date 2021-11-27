#version 120

varying vec2 uv;
varying highp float depth;

#define PER_PIXEL_LIGHTING (@normalMap || @forcePPL)

uniform mat3 shaderSettings;
#include "helpsettings.glsl"
#include "vertexcolors.glsl"

#ifdef HEIGHT_FOG
varying vec3 fogH;
#endif

uniform highp mat4 osg_ViewMatrixInverse;

varying vec3 passViewPos;

#if (PER_PIXEL_LIGHTING || @specularMap || defined(HEIGHT_FOG))
varying vec3 passNormal;
#endif

#include "shadows_vertex.glsl"

#if !PER_PIXEL_LIGHTING
    centroid varying vec3 passLighting;
    centroid varying vec3 shadowDiffuseLighting;
    #include "lighting_util.glsl"
    #include "lighting.glsl"
#endif

uniform bool radialFog;

void main(void)
{
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

    highp vec4 viewPos = (gl_ModelViewMatrix * gl_Vertex);
    gl_ClipVertex = viewPos;

if (radialFog)
    depth = length(viewPos.xyz);
else
    depth = gl_Position.z;

    passColor = gl_Color;
    passViewPos = viewPos.xyz;

#if (PER_PIXEL_LIGHTING || @specularMap || defined(HEIGHT_FOG))
    passNormal = gl_Normal.xyz;
#endif

#ifdef HEIGHT_FOG
    fogH = (osg_ViewMatrixInverse * viewPos).xyz;
#endif
    uv = gl_MultiTexCoord0.xy;

#if (!PER_PIXEL_LIGHTING || @shadows_enabled)
    vec3 viewNormal = normalize((gl_NormalMatrix * gl_Normal).xyz);
#endif

#if !PER_PIXEL_LIGHTING
    vec3 diffuseLight, ambientLight;
    doLighting(viewPos.xyz, viewNormal, diffuseLight, ambientLight, shadowDiffuseLighting);
    passLighting = colLoad(getDiffuseColor().xyz) * diffuseLight + vcolLoad(getAmbientColor().xyz) * ambientLight + colLoad(getEmissionColor().xyz);
    clampLightingResult(passLighting);
    shadowDiffuseLighting *= colLoad(getDiffuseColor().xyz);
#endif

#if (@shadows_enabled)
    setupShadowCoords(viewPos, viewNormal);
#endif
}
