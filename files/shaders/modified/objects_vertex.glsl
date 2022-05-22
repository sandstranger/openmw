#version 120

#define OBJECT
#define PER_PIXEL_LIGHTING (@normalMap || (@forcePPL && !@isParticle))

#if @diffuseMap
varying vec2 diffuseMapUV;
#endif

#if @darkMap
varying vec2 darkMapUV;
#endif

#if @detailMap
varying vec2 detailMapUV;
#endif

#if @decalMap
varying vec2 decalMapUV;
#endif

#if @normalMap
varying vec4 passTangent;
#endif

#if @envMap
varying vec2 envMapUV;
#endif

#if @glossMap
varying vec2 glossMapUV;
#endif

#if PER_PIXEL_LIGHTING || @specularMap
varying vec3 passNormal;
#endif

#ifdef HEIGHT_FOG
varying vec3 fogH;
#endif

uniform highp mat4 osg_ViewMatrixInverse;

varying highp float depth;
varying vec3 passViewPos;

uniform bool radialFog;

#include "helpsettings.glsl"
#include "vertexcolors.glsl"
#include "shadows_vertex.glsl"

#if !PER_PIXEL_LIGHTING
    centroid varying vec3 passLighting;
    centroid varying vec3 shadowDiffuseLighting;
    #include "lighting_util.glsl"
    #include "lighting.glsl"
#endif

void main(void)
{
    highp vec4 viewPos = (gl_ModelViewMatrix * gl_Vertex);
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    gl_ClipVertex = viewPos;

if(radialFog)
    depth = length(viewPos.xyz);
else
    depth = gl_Position.z;

#if (@envMap || !PER_PIXEL_LIGHTING || @shadows_enabled)
    vec3 viewNormal = normalize((gl_NormalMatrix * gl_Normal).xyz);
#endif

#if @envMap
    vec3 viewVec = normalize(viewPos.xyz);
    vec3 r = reflect( viewVec, viewNormal );
    float m = 2.0 * sqrt( r.x*r.x + r.y*r.y + (r.z+1.0)*(r.z+1.0) );
    envMapUV = vec2(r.x/m + 0.5, r.y/m + 0.5);
#endif

#if @diffuseMap
    diffuseMapUV = (gl_TextureMatrix[@diffuseMapUV] * gl_MultiTexCoord@diffuseMapUV).xy;
#endif

#if @darkMap
    darkMapUV = (gl_TextureMatrix[@darkMapUV] * gl_MultiTexCoord@darkMapUV).xy;
#endif

#if @detailMap
    detailMapUV = (gl_TextureMatrix[@detailMapUV] * gl_MultiTexCoord@detailMapUV).xy;
#endif

#if @decalMap
    decalMapUV = (gl_TextureMatrix[@decalMapUV] * gl_MultiTexCoord@decalMapUV).xy;;
#endif

#if @glossMap
    glossMapUV = (gl_TextureMatrix[@glossMapUV] * gl_MultiTexCoord@glossMapUV).xy;
#endif

#if @normalMap
    passTangent = gl_MultiTexCoord7.xyzw;
#endif

    passColor = gl_Color;
    passViewPos = viewPos.xyz;

#if PER_PIXEL_LIGHTING || @specularMap
    passNormal = gl_Normal.xyz;
#endif

#ifdef HEIGHT_FOG
    fogH = (osg_ViewMatrixInverse * viewPos).xyz;
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