#version 120

#define GRASS

#define PER_PIXEL_LIGHTING @normalMap

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

#if @normalMap
uniform sampler2D normalMap;
varying vec4 passTangent;
#endif

#include "helpsettings.glsl"
#include "tonemap.glsl"
#include "vertexcolors.glsl"
#include "lighting_util.glsl"

varying float depth;
varying float linearDepth;

uniform highp mat4 osg_ViewMatrixInverse;

varying vec3 passViewPos;

#if PER_PIXEL_LIGHTING
varying vec3 passNormal;
#endif

#if @grassDebugBatches
    uniform vec3 debugColor;
#endif

#include "shadows_fragment.glsl"

#if !PER_PIXEL_LIGHTING
    centroid varying vec3 passLighting;
    centroid varying vec3 shadowDiffuseLighting;
#else
    #include "lighting.glsl"
#endif

uniform vec2 screenRes;

uniform highp mat3 grassData;

uniform bool radialFog;
uniform bool underwaterFog;
uniform float gamma;

#include "effects.glsl"
#include "fog.glsl"
#include "alpha.glsl"

void main()
{

float underwaterFogValue;
if(underwaterFog) {
    bool isUnderwater = (osg_ViewMatrixInverse * vec4(passViewPos, 1.0)).z < -1.0 && osg_ViewMatrixInverse[3].z > -1.0;
    underwaterFogValue = (isUnderwater) ? getUnderwaterFogValue(depth) : 0.0;
}

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
    gl_FragData[0].xyz = texLoad(gl_FragData[0].xyz);
#else
    gl_FragData[0] = vec4(1.0);
#endif

#if !@grassDebugBatches
    if (depth > grassData[2].x)
        gl_FragData[0].a *= 1.0-smoothstep(grassData[2].x, grassData[2].y, depth);
#endif

    alphaTest();

    float shadowing = unshadowedLightRatio(depth);

    vec3 lighting;
#if !PER_PIXEL_LIGHTING
    lighting = (passLighting + shadowDiffuseLighting * shadowing) * Fd_Lambert();
#else
    vec3 diffuseLight, ambientLight;
    doLighting(passViewPos, normalize(viewNormal), shadowing, diffuseLight, ambientLight);
    lighting = diffuseColor.xyz * diffuseLight * Fd_Lambert() + vcolLoad(getAmbientColor().xyz) * ambientLight * Fd_Lambert() + colLoad(getEmissionColor().xyz);
    clampLightingResult(lighting);
#endif

#if @linearLighting
    gl_FragData[0].xyz *= lighting /* vcolLoad(getAmbientColor().xyz)*/;
#else
    gl_FragData[0].xyz *= lighting;
#endif

#if @linearLighting
   float exposure = getExposure(length(colLoad(lcalcDiffuse(0).xyz) + colLoad(gl_LightModel.ambient.xyz)) * 0.5);
   gl_FragData[0].xyz = toneMap(gl_FragData[0].xyz, exposure);
#endif

if(underwaterFog)
    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, uwfogcolor, underwaterFogValue);

    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/ (@gamma + gamma - 1.0)));

    gl_FragData[0] = applyFogAtDist(gl_FragData[0], depth, linearDepth);

    //gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/ (@gamma + gamma - 1.0)));

#if @grassDebugBatches
    gl_FragData[0].xyz = debugColor;
#endif
}
