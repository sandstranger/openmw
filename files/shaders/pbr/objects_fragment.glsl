#version 120

#if @useUBO
    #extension GL_ARB_uniform_buffer_object : require
#endif

#if @useGPUShader4
    #extension GL_EXT_gpu_shader4: require
#endif

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

#if @darkMap
uniform sampler2D darkMap;
varying vec2 darkMapUV;
#endif

#if @detailMap
uniform sampler2D detailMap;
varying vec2 detailMapUV;
#endif

#if @decalMap
uniform sampler2D decalMap;
varying vec2 decalMapUV;
#endif

#if @emissiveMap
uniform sampler2D emissiveMap;
varying vec2 emissiveMapUV;
#endif

#if @normalMap
uniform sampler2D normalMap;
varying vec2 normalMapUV;
varying vec4 passTangent;
#endif

#if @envMap
uniform sampler2D envMap;
varying vec2 envMapUV;
uniform vec4 envMapColor;
#endif

#if @specularMap
uniform sampler2D specularMap;
varying vec2 specularMapUV;
#endif

#if @bumpMap
uniform sampler2D bumpMap;
varying vec2 bumpMapUV;
uniform vec2 envMapLumaBias;
uniform mat2 bumpMapMatrix;
#endif

uniform bool simpleWater;
uniform bool noAlpha;

varying float euclideanDepth;
varying float linearDepth;

#define PER_PIXEL_LIGHTING (@normalMap || @forcePPL)

#if !PER_PIXEL_LIGHTING
centroid varying vec3 passLighting;
centroid varying vec3 shadowDiffuseLighting;
#else
uniform float emissiveMult;
#endif
varying vec3 passViewPos;
varying vec3 passNormal;

#include "helperutil.glsl"
#include "vertexcolors.glsl"
#include "shadows_fragment.glsl"
#include "lighting.glsl"
#include "parallax.glsl"
#include "alpha.glsl"

void main()
{
#if @diffuseMap
    vec2 adjustedDiffuseUV = diffuseMapUV;
#endif

#if @normalMap
    vec4 normalTex = texture2D(normalMap, normalMapUV);

    vec3 normalizedNormal = normalize(passNormal);
    vec3 normalizedTangent = normalize(passTangent.xyz);
    vec3 binormal = cross(normalizedTangent, normalizedNormal) * passTangent.w;
    mat3 tbnTranspose = mat3(normalizedTangent, binormal, normalizedNormal);

    vec3 viewNormal = gl_NormalMatrix * normalize(tbnTranspose * (normalTex.xyz * 2.0 - 1.0));
#endif

#if (!@normalMap && (@parallax || @forcePPL))
    vec3 viewNormal = gl_NormalMatrix * normalize(passNormal);
#endif

#if @parallax
    vec3 cameraPos = (gl_ModelViewMatrixInverse * vec4(0,0,0,1)).xyz;
    vec3 objectPos = (gl_ModelViewMatrixInverse * vec4(passViewPos, 1)).xyz;
    vec3 eyeDir = normalize(cameraPos - objectPos);
    vec2 offset = getParallaxOffset(eyeDir, tbnTranspose, normalTex.a, (passTangent.w > 0.0) ? -1.f : 1.f);
    adjustedDiffuseUV += offset; // only offset diffuse for now, other textures are more likely to be using a completely different UV set

    // TODO: check not working as the same UV buffer is being bound to different targets
    // if diffuseMapUV == normalMapUV
#if 1
    // fetch a new normal using updated coordinates
    normalTex = texture2D(normalMap, adjustedDiffuseUV);
    viewNormal = gl_NormalMatrix * normalize(tbnTranspose * (normalTex.xyz * 2.0 - 1.0));
#endif

#endif

#if @diffuseMap
    gl_FragData[0] = texture2D(diffuseMap, adjustedDiffuseUV);
	gl_FragData[0].rgb = SRGBToLinear(gl_FragData[0].rgb);
    gl_FragData[0].a *= coveragePreservingAlphaScale(diffuseMap, adjustedDiffuseUV);
#else
    gl_FragData[0] = vec4(1.0);
#endif

    vec4 diffuseColor = getDiffuseColor();
	diffuseColor.rgb = SRGBToLinearApprox(diffuseColor.rgb);
    gl_FragData[0].a *= diffuseColor.a;

#if @darkMap
    gl_FragData[0] *= texture2D(darkMap, darkMapUV);
    gl_FragData[0].a *= coveragePreservingAlphaScale(darkMap, darkMapUV);
#endif

    alphaTest();

#if @detailMap
    gl_FragData[0].xyz *= texture2D(detailMap, detailMapUV).xyz * 2.0;
#endif

#if @decalMap
    vec4 decalTex = texture2D(decalMap, decalMapUV);
	decalTex.rgb = SRGBToLinear(decalTex.rgb);
    gl_FragData[0].xyz = mix(gl_FragData[0].xyz, decalTex.xyz, decalTex.a);
#endif

#if @envMap

    vec2 envTexCoordGen = envMapUV;
    float envLuma = 1.0;

#if @normalMap
    // if using normal map + env map, take advantage of per-pixel normals for envTexCoordGen
    vec3 viewVec = normalize(passViewPos.xyz);
    vec3 r = reflect( viewVec, viewNormal );
    float m = 2.0 * sqrt( r.x*r.x + r.y*r.y + (r.z+1.0)*(r.z+1.0) );
    envTexCoordGen = vec2(r.x/m + 0.5, r.y/m + 0.5);
#endif

#if @bumpMap
    vec4 bumpTex = texture2D(bumpMap, bumpMapUV);
    envTexCoordGen += bumpTex.rg * bumpMapMatrix;
    envLuma = clamp(bumpTex.b * envMapLumaBias.x + envMapLumaBias.y, 0.0, 1.0);
#endif

#if @preLightEnv
    gl_FragData[0].xyz += texture2D(envMap, envTexCoordGen).xyz * envMapColor.xyz * envLuma;
#endif

#endif

    float shadowing = unshadowedLightRatio(linearDepth);
    vec3 lighting;
#if !PER_PIXEL_LIGHTING
    lighting = passLighting + shadowDiffuseLighting * shadowing;
	gl_FragData[0].xyz *= lighting * Fd_Lambert();
#else
    vec3 diffuseLight, ambientLight;
    doLighting(passViewPos, normalize(viewNormal), shadowing, diffuseLight, ambientLight);
    vec3 emission = SRGBToLinearApprox(getEmissionColor().xyz) * emissiveMult;

	vec3 specularBRDF = vec3(0.0,0.0,0.0);

	float microAO = 1.0;

	#if @specularMap
	vec4 param = vec4(0.0, 0.98, 0.5, 1.0);

	param = texture2D(specularMap, adjustedDiffuseUV);

	float metallic = param.x; // maps should have 1 for metals
	float roughness = max(0.015, param.y * param.y); //linear roughness
	float reflectance = param.z; // 0.5 to 0.04 see conversion below
	float AO = param.a;

	//gl_FragData[0].xyz = (1.0 - metallic) * gl_FragData[0].xyz;
	vec3 f0 = vec3(0.16,0.16,0.16) * reflectance * reflectance;

	vec3 l = normalize(lcalcPosition(0));

	vec3 v = normalize(-passViewPos.xyz);

	vec3 n = normalize(viewNormal);

	float aoFadeTerm = clamp(dot(gl_NormalMatrix * normalize(passNormal), v), 0.0, 1.0);
	AO = mix(1.0, AO, aoFadeTerm);

	microAO = applyAO(AO, dot(l, n)); 

	BRDF(v, l, n, roughness, f0, specularBRDF);
	specularBRDF *= microAO;
	#endif
	
	vec3 diffuseBRDF = diffuseColor.xyz * diffuseLight * Fd_Lambert()+ microAO * sqrt(getAmbientColor().xyz) * ambientLight * Fd_Lambert() + emission;

	#ifdef PBRDEBUG
	gl_FragData[0].xyz = specularBRDF;
	#else
	gl_FragData[0].xyz = gl_FragData[0].xyz * diffuseBRDF + sqrt(getAmbientColor().xyz) * specularBRDF * shadowing * SRGBToLinearApprox(lcalcDiffuse(0).xyz);
	#endif
#endif

#if @envMap && !@preLightEnv
    gl_FragData[0].xyz += SRGBToLinear(texture2D(envMap, envTexCoordGen).xyz) * envMapColor.xyz * envLuma;
#endif

#if @emissiveMap
    gl_FragData[0].xyz += SRGBToLinear(texture2D(emissiveMap, emissiveMapUV).xyz);
#endif

#if @specularMap
    vec4 specTex = texture2D(specularMap, specularMapUV);
    float shininess = specTex.a * 255.0;
    vec3 matSpec = specTex.xyz;
#else
    float shininess = gl_FrontMaterial.shininess;
    vec3 matSpec = getSpecularColor().xyz;
#endif

    if (matSpec != vec3(0.0))
    {
#if (!@normalMap && !@parallax && !@forcePPL)
        vec3 viewNormal = gl_NormalMatrix * normalize(passNormal);
#endif
        //gl_FragData[0].xyz += getSpecular(normalize(viewNormal), normalize(passViewPos.xyz), shininess, matSpec) * shadowing;
    }
#if @radialFog
    float depth;
    // For the less detailed mesh of simple water we need to recalculate depth on per-pixel basis
    if (simpleWater)
        depth = length(passViewPos);
    else
        depth = euclideanDepth;
    float fogValue = clamp((depth - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
#else
    float fogValue = clamp((linearDepth - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
#endif

	float exposure = mix(3.6, 2.6, length(SRGBToLinearApprox(lcalcDiffuse(0).xyz) + SRGBToLinearApprox(gl_LightModel.ambient.xyz)) * 0.5);

	// spare maps and paper toy
	if (noAlpha || gl_Fog.start > 9000000.0) {
		exposure = 1.0;
	}
	
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

	#if @translucentFramebuffer
    // having testing & blending isn't enough - we need to write an opaque pixel to be opaque
	exposure = 1.0;
    if (noAlpha)
        gl_FragData[0].a = 1.0;
	#endif

    applyShadowDebugOverlay();
}
