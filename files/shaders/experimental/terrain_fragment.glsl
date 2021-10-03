#version 120

#define TERRAIN

varying vec2 uv;

uniform sampler2D diffuseMap;

#if @normalMap
uniform sampler2D normalMap;
#endif

#if @blendMap
uniform sampler2D blendMap;
#endif

varying float depth;

#define PER_PIXEL_LIGHTING (@normalMap || @forcePPL)

uniform vec4 shaderSettings;
#include "tonemap.glsl"
#include "helpsettings.glsl"
#include "vertexcolors.glsl"
#include "lighting_util.glsl"

uniform mat4 osg_ViewMatrixInverse;

#ifdef ANIMATED_HEIGHT_FOG
uniform float osg_SimulationTime;
#endif

uniform bool skip;
varying vec3 passViewPos;

varying vec3 passNormal;

centroid varying vec3 passLighting;

  #ifdef LINEAR_LIGHTING
    #include "linear_lighting.glsl"
  #else
    #include "lighting.glsl"
  #endif

#include "effects.glsl"
#include "fog.glsl"


void main()
{
    bool clampLighting = (shaderSettings.y == 2.0 || shaderSettings.y == 3.0 || shaderSettings.y == 6.0 || shaderSettings.y == 7.0) ? true : false;
    bool PPL = (shaderSettings.y == 4.0 || shaderSettings.y == 5.0 || shaderSettings.y == 6.0 || shaderSettings.y == 7.0 || @normalMap == 1) ? true : false;

    bool parallaxShadows = (shaderSettings.z == 1.0 || shaderSettings.z == 3.0 || shaderSettings.z == 5.0 || shaderSettings.z == 7.0) ? true : false;
    bool underwaterFog = (shaderSettings.z == 2.0 || shaderSettings.z == 3.0 || shaderSettings.z == 6.0 || shaderSettings.z == 7.0) ? true : false;

    bool isUnderwater = (osg_ViewMatrixInverse * vec4(passViewPos, 1.0)).z < -1.0 && osg_ViewMatrixInverse[3].z >= -1.0 && !skip;

    float underwaterFogValue = (isUnderwater) ? getUnderwaterFogValue(depth) : 0.0;
    float fogValue = getFogValue(depth);

//if((underwaterFog && fogValue < 1.0 && underwaterFogValue < 1.0) || (!underwaterFog && fogValue < 1.0))
{
    float shadowpara = 1.0;

    vec2 adjustedUV = (gl_TextureMatrix[0] * vec4(uv, 0.0, 1.0)).xy;

   vec3 viewNormal = gl_NormalMatrix * normalize(passNormal);

#if @normalMap
    #ifdef NORMAL_MAP_FADING
        if(!skip) {
    #endif
    vec4 normalTex = texture2D(normalMap, adjustedUV);

    vec3 normalizedNormal = normalize(passNormal);
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = normalize(cross(tangent, normalizedNormal));
    tangent = normalize(cross(normalizedNormal, binormal)); // note, now we need to re-cross to derive tangent again because it wasn't orthonormal
    mat3 tbnTranspose = mat3(tangent, binormal, normalizedNormal);
    viewNormal = normalize(gl_NormalMatrix * (tbnTranspose * (normalTex.xyz * 2.0 - 1.0)));

#if @parallax
    vec3 cameraPos = (gl_ModelViewMatrixInverse * vec4(0,0,0,1)).xyz;
    vec3 objectPos = (gl_ModelViewMatrixInverse * vec4(passViewPos, 1)).xyz;
    vec3 eyeDir = normalize(cameraPos - objectPos);

    if(parallaxShadows)
        shadowpara = getParallaxShadow(normalTex.a, adjustedUV);

    adjustedUV += getParallaxOffset(eyeDir, tbnTranspose, normalTex.a, 1.f);

    // update normal using new coordinates
    normalTex = texture2D(normalMap, adjustedUV);
#endif
    #ifdef NORMAL_MAP_FADING
        }
    #endif
#endif

    vec4 diffuseTex = texture2D(diffuseMap, adjustedUV);
    gl_FragData[0] = vec4(diffuseTex.xyz, 1.0);

#if @blendMap
    vec2 blendMapUV = (gl_TextureMatrix[1] * vec4(uv, 0.0, 1.0)).xy;
    gl_FragData[0].a *= texture2D(blendMap, blendMapUV).a;
#endif

    gl_FragData[0].xyz = preLight(gl_FragData[0].xyz);

    vec4 diffuseColor = getDiffuseColor();
    gl_FragData[0].a *= diffuseColor.a;

    vec3 lighting;

if(!PPL)
    lighting = passLighting;
else {
#ifdef LINEAR_LIGHTING
    lighting.xyz = doLighting(passViewPos, normalize(viewNormal), passColor, shadowpara).xyz;
#else
    vec3 diffuseLight, ambientLight, shadowDiffuseLight;
    doLighting(passViewPos, normalize(viewNormal), diffuseLight, ambientLight, shadowDiffuseLight, shadowpara, true);
    lighting = diffuseColor.xyz * diffuseLight + getAmbientColor().xyz * ambientLight + getEmissionColor().xyz;
#endif
    clampLightingResult(lighting, clampLighting);
}

    gl_FragData[0].xyz *= lighting;

#if @specularMap
    float shininess = 128.0; // TODO: make configurable
    vec3 matSpec = vec3(diffuseTex.a);
    gl_FragData[0].xyz += getSpecular(normalize(viewNormal), normalize(passViewPos), shininess, matSpec) * shadowpara;
#endif

   gl_FragData[0].xyz = toneMap(gl_FragData[0].xyz);

#ifdef LINEAR_LIGHTING
        gl_FragData[0].xyz = SpecialContrast(gl_FragData[0].xyz, mix(connight, conday, lcalcDiffuse(0).x));
#endif

}

if(underwaterFog)
    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, uwfogcolor, underwaterFogValue);

if(!isUnderwater)
    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, gl_Fog.color.xyz, fogValue);

    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/shaderSettings.w));
}
