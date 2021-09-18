vec3 LessThan(vec3 f, float value) {
	return vec3(
		(f.x < value) ? 1.0f : 0.0f,
		(f.y < value) ? 1.0f : 0.0f,
		(f.z < value) ? 1.0f : 0.0f);
}

vec3 LinearToSRGB(vec3 rgb) {
	rgb = clamp(rgb, 0.0f, 1.0f);

	return mix(
		pow(rgb, vec3(1.0f / 2.4f)) * 1.055f - 0.055f,
		rgb * 12.92f,
		LessThan(rgb, 0.0031308f)
	);
}

vec3 SRGBToLinear(vec3 rgb) {
	rgb = clamp(rgb, 0.0f, 1.0f);

	return mix(
		pow(((rgb + 0.055f) / 1.055f), vec3(2.4f)),
		rgb / 12.92f,
		LessThan(rgb, 0.04045f)
	);
}

vec3 SRGBToLinearApprox(vec3 sRGB) {
	vec3 RGB = sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
	return RGB;
}

// ACES tone mapping curve fit to go from HDR to LDR
//https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x) {
	float a = 2.51f;
	float b = 0.03f;
	float c = 2.43f;
	float d = 0.59f;
	float e = 0.14f;
	return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0f, 1.0f);
}

/* PBR Cook Torrance */

#define PI 3.141592653589793238462643383279502884197169

float D_GGX(float NoH, float roughness) {
	float oneMinusNoHSquared = 1.0 - NoH * NoH;
	float a = NoH * roughness;
    float k = roughness / (oneMinusNoHSquared + a * a);
    float d = k * k * (1.0 / PI);
    return d;
}

vec3 F_Schlick(float VoH, vec3 f0) {
	return f0 + (vec3(1.0) - f0) * pow(1.0 - VoH, 5.0);
}

float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = roughness * roughness;
 
    float lambdaV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
    float lambdaL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
	float v = 0.5 / (max(lambdaV + lambdaL, 1e-5));
    return v;
}

float G_Kelemen(float NoL, float NoV, float VoH) {
	float a = NoL * NoV;
	float b = VoH * VoH;
	return a/b;
}

float Fd_Lambert() {
    return 1.0 / PI;
}

float applyAO(float ao, float sNoL) {
	float aperture = 2.0 * ao * ao;
	float microShadow = abs(sNoL) + aperture - 1.0;
	return clamp(microShadow, 0.0, 1.0);
}

/* for completeness
	vec3 l = normalize(lcalcPosition(0));
	vec3 v = normalize(-passViewPos.xyz);
	vec3 n = normalize(viewNormal);

	BRDF(v, l, n, roughness, f0, diffuseBRDF, specularBRDF);
*/

//uniform float osg_SimulationTime;

//#define PBRDEBUG
void BRDF(vec3 v, vec3 l, vec3 n, float roughness, vec3 f0, inout vec3 specularBRDF) {
	vec3 h = normalize(v + l);
	float NoV = clamp(dot(n, v), 0.0, 1.0);
	float NoL = clamp(dot(n, l), 0.0, 1.0);
	float NoH = clamp(dot(n, h), 0.0, 1.0);
	float LoH = clamp(dot(l, h), 0.0, 1.0);
	float VoH = clamp(dot(v, h), 0.0, 1.0);
	
	//float f90 = clamp(dot(f0, vec3(50.0 * 0.33)), 0.0, 1.0);
	
	vec3  F = F_Schlick(LoH, f0);
	float G = V_SmithGGXCorrelated(NoV, NoL, roughness);
	float D = D_GGX(NoH, roughness);
	
	
	
	// specular BRDF
	specularBRDF = (D * G) * F * NoL;

	
	#ifdef PBRDEBUG // DEBUG
	//specularBRDF = vec3(D) * NoL;
	//specularBRDF = vec3(F) * NoL;
	//specularBRDF = vec3(G) * NoL;
	//specularBRDF = specularBRDF * NoL;
	specularBRDF = vec3(roughness);
	#endif
}

/* for completeness
	diffuseBRDF *= lighting * AO;
	gl_FragData[0].xyz = gl_FragData[0].xyz * Fd_Lambert() * diffuseBRDF + specularBRDF * shadowing * SRGBToLinearApprox(lcalcDiffuse(0).xyz);
*/
