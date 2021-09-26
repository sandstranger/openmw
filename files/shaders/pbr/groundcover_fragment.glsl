#version 120

#if @useUBO
    #extension GL_ARB_uniform_buffer_object : require
#endif

#if @useGPUShader4
    #extension GL_EXT_gpu_shader4: require
#endif

#define GROUNDCOVER

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

#if @normalMap
uniform sampler2D normalMap;
varying vec2 normalMapUV;
varying vec4 passTangent;
#endif

// Other shaders respect forcePPL, but legacy groundcover mods were designed to work with vertex lighting.
// They may do not look as intended with per-pixel lighting, so ignore this setting for now.
#define PER_PIXEL_LIGHTING @normalMap

varying float depth;

#if PER_PIXEL_LIGHTING
varying vec3 passViewPos;
varying vec3 passNormal;
#else
centroid varying vec3 passLighting;
#endif

#include "helperutil.glsl"
#include "shadows_fragment.glsl"
#include "lighting.glsl"
#include "alpha.glsl"

uniform mat3 grassData;

void main()
{

if(grassData[2].y != grassData[2].x)
    if (depth > grassData[2].y)
        discard;

#if @normalMap
    vec4 normalTex = texture2D(normalMap, normalMapUV);

    vec3 normalizedNormal = normalize(passNormal);
    vec3 normalizedTangent = normalize(passTangent.xyz);
    vec3 binormal = cross(normalizedTangent, normalizedNormal) * passTangent.w;
    mat3 tbnTranspose = mat3(normalizedTangent, binormal, normalizedNormal);

    vec3 viewNormal = gl_NormalMatrix * normalize(tbnTranspose * (normalTex.xyz * 2.0 - 1.0));
#endif

#if @diffuseMap
    gl_FragData[0] = texture2D(diffuseMap, diffuseMapUV);
	gl_FragData[0].rgb = SRGBToLinear(gl_FragData[0].rgb);
#else
    gl_FragData[0] = vec4(1.0);
#endif

    if (depth > grassData[2].x)
        gl_FragData[0].a *= 1.0-smoothstep(grassData[2].x, grassData[2].y, depth);

    alphaTest();

    float shadowing = unshadowedLightRatio(depth);

    vec3 lighting;
#if !PER_PIXEL_LIGHTING
    lighting = passLighting;
#else
    vec3 diffuseLight, ambientLight;
    doLighting(passViewPos, normalize(viewNormal), shadowing, diffuseLight, ambientLight);
    lighting = diffuseLight + ambientLight;
    clampLightingResult(lighting);
#endif

    gl_FragData[0].xyz *= lighting * Fd_Lambert();

    float fogValue = clamp((depth - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);

	float exposure = mix(4.6, 2.6, length(SRGBToLinearApprox(lcalcDiffuse(0).xyz) + SRGBToLinearApprox(gl_LightModel.ambient.xyz)) * 0.5);
	
	
	#ifdef PBRDEBUG
	gl_FragData[0].xyz *= 1.0;
	#else
	gl_FragData[0].xyz *= pow(2.0, exposure);
	
	
    // convert unbounded HDR color range to SDR color range
    gl_FragData[0].xyz = ACESFilm(gl_FragData[0].xyz);
 
    // convert from linear to sRGB for display
    gl_FragData[0].xyz = LinearToSRGB(gl_FragData[0].xyz);
	#endif

    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, gl_Fog.color.xyz, fogValue);

    applyShadowDebugOverlay();
}
