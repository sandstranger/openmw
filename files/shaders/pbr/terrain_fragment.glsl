#version 120

#if @useUBO
    #extension GL_ARB_uniform_buffer_object : require
#endif

#if @useGPUShader4
    #extension GL_EXT_gpu_shader4: require
#endif

varying vec2 uv;

uniform sampler2D diffuseMap;

#if @normalMap
uniform sampler2D normalMap;
#endif

#if @blendMap
uniform sampler2D blendMap;
#endif

varying float euclideanDepth;
varying float linearDepth;

#define PER_PIXEL_LIGHTING (@normalMap || @forcePPL)

#if !PER_PIXEL_LIGHTING
centroid varying vec3 passLighting;
centroid varying vec3 shadowDiffuseLighting;
#endif
varying vec3 passViewPos;
varying vec3 passNormal;

#include "helperutil.glsl"
#include "vertexcolors.glsl"
#include "shadows_fragment.glsl"
#include "lighting.glsl"
#include "parallax.glsl"

void main()
{
    vec2 adjustedUV = (gl_TextureMatrix[0] * vec4(uv, 0.0, 1.0)).xy;

#if @normalMap
    vec4 normalTex = texture2D(normalMap, adjustedUV);

    vec3 normalizedNormal = normalize(passNormal);
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = normalize(cross(tangent, normalizedNormal));
    tangent = normalize(cross(normalizedNormal, binormal)); // note, now we need to re-cross to derive tangent again because it wasn't orthonormal
    mat3 tbnTranspose = mat3(tangent, binormal, normalizedNormal);

    vec3 viewNormal = normalize(gl_NormalMatrix * (tbnTranspose * (normalTex.xyz * 2.0 - 1.0)));
#endif

#if (!@normalMap && (@parallax || @forcePPL))
    vec3 viewNormal = gl_NormalMatrix * normalize(passNormal);
#endif

#if @parallax
    vec3 cameraPos = (gl_ModelViewMatrixInverse * vec4(0,0,0,1)).xyz;
    vec3 objectPos = (gl_ModelViewMatrixInverse * vec4(passViewPos, 1)).xyz;
    vec3 eyeDir = normalize(cameraPos - objectPos);
    adjustedUV += getParallaxOffset(eyeDir, tbnTranspose, normalTex.a, 1.f);

    // update normal using new coordinates
    normalTex = texture2D(normalMap, adjustedUV);
    viewNormal = normalize(gl_NormalMatrix * (tbnTranspose * (normalTex.xyz * 2.0 - 1.0)));
#endif

    vec4 diffuseTex = texture2D(diffuseMap, adjustedUV);
	diffuseTex.xyz = SRGBToLinear(diffuseTex.xyz);
    gl_FragData[0] = vec4(diffuseTex.xyz, 1.0);

#if @blendMap
    vec2 blendMapUV = (gl_TextureMatrix[1] * vec4(uv, 0.0, 1.0)).xy;
    gl_FragData[0].a *= texture2D(blendMap, blendMapUV).a;
#endif

    vec4 diffuseColor = getDiffuseColor();
	diffuseColor.rgb = SRGBToLinearApprox(diffuseColor.rgb);
    gl_FragData[0].a *= diffuseColor.a;

    float shadowing = unshadowedLightRatio(linearDepth);
    vec3 lighting;
#if !PER_PIXEL_LIGHTING
    lighting = passLighting + shadowDiffuseLighting * shadowing;
	gl_FragData[0].xyz *= lighting * Fd_Lambert();
#else
    vec3 diffuseLight, ambientLight;
    doLighting(passViewPos, normalize(viewNormal), shadowing, diffuseLight, ambientLight);

	vec3 specularBRDF = vec3(0.0,0.0,0.0);

	//float microAO = 1.0;

	#if @specularMap
	vec4 param = vec4(0.0, 0.98, 0.5, 1.0);

	float metallic = param.x; // maps should have 1 for metals
	float roughness = max(0.015, diffuseTex.a * diffuseTex.a); //linear roughness
	float reflectance = param.z; // 0.5 to 0.04 see conversion below

	gl_FragData[0].xyz = (1.0 - metallic) * gl_FragData[0].xyz;
	vec3 f0 = vec3(0.16,0.16,0.16) * reflectance * reflectance;

	vec3 l = normalize(lcalcPosition(0));

	vec3 v = normalize(-passViewPos.xyz);

	vec3 n = normalize(viewNormal);

	BRDF(v, l, n, roughness, f0, specularBRDF);
	#endif
	vec3 diffuseBRDF = diffuseColor.xyz * diffuseLight * Fd_Lambert() + sqrt(getAmbientColor().xyz) * ambientLight * Fd_Lambert() + SRGBToLinearApprox(getEmissionColor().xyz);

	#ifdef PBRDEBUG
	gl_FragData[0].xyz = specularBRDF;
	#else
	gl_FragData[0].xyz = gl_FragData[0].xyz * diffuseBRDF + sqrt(getAmbientColor().xyz) * specularBRDF * shadowing * SRGBToLinearApprox(lcalcDiffuse(0).xyz);
	#endif
#endif

#if @specularMap
    float shininess = 128.0; // TODO: make configurable
    vec3 matSpec = vec3(diffuseTex.a);
#else
    float shininess = gl_FrontMaterial.shininess;
    vec3 matSpec = getSpecularColor().xyz;
#endif

    if (matSpec != vec3(0.0))
    {
#if (!@normalMap && !@parallax && !@forcePPL)
        vec3 viewNormal = gl_NormalMatrix * normalize(passNormal);
#endif
        //gl_FragData[0].xyz += getSpecular(normalize(viewNormal), normalize(passViewPos), shininess, matSpec) * shadowing;
    }

#if @radialFog
    float fogValue = clamp((euclideanDepth - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
#else
    float fogValue = clamp((linearDepth - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
#endif

	float exposure = mix(3.6, 2.6, length(SRGBToLinearApprox(lcalcDiffuse(0).xyz) + SRGBToLinearApprox(gl_LightModel.ambient.xyz)) * 0.5);

	#ifdef PBRDEBUG
	gl_FragData[0].xyz *= 1.0;
	#else
	gl_FragData[0].xyz *= pow(2.0, exposure);

	// convert unbounded HDR color range to SDR color range
	gl_FragData[0].xyz = clamp(ACESFilm(gl_FragData[0].xyz), vec3(0.0), vec3(1.0));

	// convert from linear to sRGB for display
	gl_FragData[0].xyz = LinearToSRGB(gl_FragData[0].xyz);
	#endif

	gl_FragData[0].xyz = mix(gl_FragData[0].xyz, gl_Fog.color.xyz, fogValue);

    applyShadowDebugOverlay();
}
