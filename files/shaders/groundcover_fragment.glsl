#version 120

#define GROUNDCOVER

#define PER_PIXEL_LIGHTING @normalMap

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

#if @normalMap
uniform sampler2D normalMap;
varying vec4 passTangent;
#endif

#include "vertexcolors.glsl"

varying float depth;

#if !@radialFog
varying float linearDepth;
#endif

uniform vec2 screenRes;

#if PER_PIXEL_LIGHTING
varying vec3 passViewPos;
varying vec3 passNormal;
#endif

#if @grassDebugBatches
    uniform vec3 debugColor;
#endif

uniform mat3 grassData;

#if PER_PIXEL_LIGHTING
    #include "lighting.glsl"
#else
    #include "lighting_util.glsl"
     centroid varying vec3 passLighting;
#endif

#include "alpha.glsl"
#include "fog.glsl"

void main()
{

#if !@grassDebugBatches
if(grassData[2].y != grassData[2].x)
    if (depth > grassData[2].y)
        discard;
#endif

#if @normalMap
vec4 normalTex = texture2D(normalMap, diffuseMapUV);
vec3 normalizedNormal = normalize(passNormal);
vec3 normalizedTangent = normalize(passTangent.xyz);
vec3 binormal = cross(normalizedTangent, normalizedNormal) * passTangent.w;
mat3 tbnTranspose = mat3(normalizedTangent, binormal, normalizedNormal);
vec3 viewNormal = gl_NormalMatrix * normalize(tbnTranspose * (normalTex.xyz * 2.0 - 1.0));
#endif

#if @diffuseMap
    gl_FragData[0] = texture2D(diffuseMap, diffuseMapUV);
#else
    gl_FragData[0] = vec4(1.0);
#endif

#if !@grassDebugBatches
    if (depth > grassData[2].x)
        gl_FragData[0].a *= 1.0-smoothstep(grassData[2].x, grassData[2].y, depth);
#endif

    alphaTest();

    vec3 lighting;
#if !PER_PIXEL_LIGHTING
    lighting = passLighting;
#else
    vec3 diffuseLight, ambientLight;
    doLighting(passViewPos, normalize(viewNormal), 1.0, diffuseLight, ambientLight);
    lighting = diffuseLight + ambientLight;
#endif

    clampLightingResult(lighting);
    gl_FragData[0].xyz *= lighting;

#if @radialFog
    gl_FragData[0] = applyFogAtDist(gl_FragData[0], depth, 0.0);
#else
    gl_FragData[0] = applyFogAtDist(gl_FragData[0], 0.0, linearDepth);
#endif

    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/@gamma));

#if @grassDebugBatches
    gl_FragData[0].xyz = debugColor;
#endif

	gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/@gamma));

}
