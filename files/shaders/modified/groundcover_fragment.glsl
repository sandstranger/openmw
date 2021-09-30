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

uniform vec4 shaderSettings;
#include "tonemap.glsl"

#include "helpsettings.glsl"
#include "vertexcolors.glsl"
#include "lighting_util.glsl"

varying float depth;

uniform highp mat4 osg_ViewMatrixInverse;

#ifdef ANIMATED_HEIGHT_FOG
uniform float osg_SimulationTime;
#endif

varying vec3 passViewPos;

#if PER_PIXEL_LIGHTING
varying vec3 passNormal;
#endif

#if PER_PIXEL_LIGHTING
  #ifdef LINEAR_LIGHTING
    #include "linear_lighting.glsl"
  #else
    #include "lighting.glsl"
  #endif
#else
  centroid varying vec3 passLighting;
#endif

#include "effects.glsl"
#include "fog.glsl"
#include "alpha.glsl"

uniform highp mat3 grassData;

void main()
{
    bool underwaterFog = (shaderSettings.y == 1.0 || shaderSettings.y == 3.0 || shaderSettings.y == 5.0 || shaderSettings.y == 7.0) ? true : false;
    bool clampLighting = (shaderSettings.y == 4.0 || shaderSettings.y == 5.0 || shaderSettings.y == 6.0 || shaderSettings.y == 7.0) ? true : false;

    bool isUnderwater = (osg_ViewMatrixInverse * vec4(passViewPos, 1.0)).z < -1.0 && osg_ViewMatrixInverse[3].z > -1.0;
    float underwaterFogValue = (isUnderwater) ? getUnderwaterFogValue(depth) : 0.0;

    float fogValue = getFogValue(depth);


if(grassData[2].y != grassData[2].x)
    if (depth > grassData[2].y)
        discard;

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

    if (depth > grassData[2].x)
        gl_FragData[0].a *= 1.0-smoothstep(grassData[2].x, grassData[2].y, depth);

    alphaTest();

    gl_FragData[0].xyz = preLight(gl_FragData[0].xyz);

    vec3 lighting;
#if !PER_PIXEL_LIGHTING
    lighting = passLighting;
#else
#ifdef LINEAR_LIGHTING
    lighting = doLighting(passViewPos, normalize(viewNormal), passColor, 1.0);
#else
    vec3 diffuseLight, ambientLight;
    doLighting(passViewPos, normalize(viewNormal), 1.0, diffuseLight, ambientLight);
    lighting = diffuseLight + ambientLight;
#endif
    clampLightingResult(lighting, clampLighting);
#endif

gl_FragData[0].xyz *= lighting;

   gl_FragData[0].xyz = toneMap(gl_FragData[0].xyz);

#ifdef LINEAR_LIGHTING
        gl_FragData[0].xyz = SpecialContrast(gl_FragData[0].xyz, mix(connight, conday, lcalcDiffuse(0).x));
#endif


if(underwaterFog)
    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, uwfogcolor, underwaterFogValue);

    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, gl_Fog.color.xyz, fogValue);

    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/shaderSettings.w));
}
