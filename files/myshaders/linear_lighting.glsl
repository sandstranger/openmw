#include "lightsettings.glsl"

#define LIGHTING_MODEL_FFP 0
#define LIGHTING_MODEL_SINGLE_UBO 1
#define LIGHTING_MODEL_PER_OBJECT_UNIFORM 2
#define getLight LightBuffer

float quickstep(float x)
{
    x = clamp(x, 0.0, 1.0);
    x = 1.0 - x*x;
    x = 1.0 - x*x;
    return x;
}

struct LightData
{
    vec4 position;
    vec4 diffuse;
    vec4 ambient;
    vec4 specular;
    vec4 attenuation;   // constant, linear, quadratic, radius
};

uniform LightData LightBuffer[@maxLights];
uniform int PointLightCount;

vec3 ToLinearColApprox(vec3 col) {
    return col * col;
}

vec3 Remap(vec3 original_value, vec3 new_min, vec3 new_max)
{
   return new_min + (original_value * (new_max - new_min));
}

float orenNayarDiffuse(
  vec3 lightDirection,
  vec3 viewDirection,
  vec3 surfaceNormal,
  float roughness) {
  
  float LdotV = dot(lightDirection, viewDirection);
  float NdotL = dot(lightDirection, surfaceNormal);
  float NdotV = dot(surfaceNormal, viewDirection);

  float s = LdotV - NdotL * NdotV;
  float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

  float sigma2 = roughness * roughness;
  float A = 1.0 + sigma2 * (0.18 / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
  float B = 0.45 * sigma2 / (sigma2 + 0.09);

  return max(0.0, NdotL) * (A + B * s / t) / 3.1415;
}

void LightSun(out vec3 ambientOut, out vec3 diffuseOut, int lightIndex, vec3 viewPos, vec3 viewNormal, vec4 diffuse, vec3 ambient)
{
    vec3 lightDir;

    lightDir = getLight[lightIndex].position.xyz - (viewPos.xyz * getLight[lightIndex].position.w);
    lightDir = normalize(lightDir);

    vec3 sunbounce = mix(vec3(0.0), getLight[lightIndex].diffuse.xyz, gl_LightModel.ambient.xyz);
	  sunbounce = sunbexp * mix(sunbounce, vec3(0.18), 0.5 * getLight[lightIndex].diffuse.x) * clamp((dot(viewNormal.xyz, -lightDir) + 0.4) /((1.0 + 0.4) * (1.0 + 0.4)), 0.0 ,1.0);
		
    ambientOut = sunbounce;    
    diffuseOut = sunexp * diffuse.xyz * ToLinearColApprox(getLight[lightIndex].diffuse.xyz) * orenNayarDiffuse(lightDir, viewNormal.xyz,viewNormal.xyz, 0.1);
}

void perLight(out vec3 ambientOut, out vec3 diffuseOut, int lightIndex, vec3 viewPos, vec3 viewNormal, vec4 diffuse, vec3 ambient)
{
    vec3 lightDir;
    float lightDistance;

    lightDir = getLight[lightIndex].position.xyz - (viewPos.xyz * getLight[lightIndex].position.w);
    lightDistance = length(lightDir);
    lightDir = normalize(lightDir);

    // This has a *considerable* performance uplift where GPU is a bottleneck
    if (lightDistance > getLight[lightIndex].attenuation.w * 2.0)
    {
        ambientOut = vec3(0.0);
        diffuseOut = vec3(0.0);
        return;
    }

    #ifdef ATTEN_FIX
        float illumination = clamp(1.0 / (getLight[lightIndex].attenuation.x * 0.1 + 0.01 * getLight[lightIndex].attenuation.y * lightDistance * lightDistance) - 0.054, 0.0, 1.0);
        illumination = clamp(illumination * illumination, 0.0, 1.0);
    #else
        float illumination = clamp(1.0 / (getLight[lightIndex].attenuation.x + getLight[lightIndex].attenuation.y * lightDistance + getLight[lightIndex].attenuation.z * lightDistance * lightDistance), 0.0, 1.0);
        illumination *= 1.0 - quickstep((lightDistance / (getLight[lightIndex].attenuation.w)) - 1.0);
    #endif

    ambientOut = vec3(0.0); // * gl_LightSource[lightIndex].ambient.xyz * illumination;
    float lambert = dot(viewNormal.xyz, lightDir) * illumination;
    
#ifndef GRASS
    lambert = max(lambert, 0.0);
#else
    float eyeCosine = dot(normalize(viewPos), viewNormal.xyz);
    if (lambert < 0.0)
    {
        lambert = -lambert;
        eyeCosine = -eyeCosine;
    }
    lambert *= clamp(-8.0 * (1.0 - 0.3) * eyeCosine + 1.0, 0.3, 1.0);
#endif

    //diffuseOut = getLight[lightIndex].diffuse.xyz * lambert;

    diffuseOut = mix(pnightexp, pdayexp, getLight[0].diffuse.x) * diffuse.xyz * ToLinearColApprox(getLight[lightIndex].diffuse.xyz) * lambert;
}

void perNegativeLight(out vec3 ambientOut, out vec3 diffuseOut, int lightIndex, vec3 viewPos, vec3 viewNormal, vec4 diffuse, vec3 ambient)
{
    vec3 lightDir;
    float lightDistance;

    lightDir = getLight[lightIndex].position.xyz - (viewPos.xyz * getLight[lightIndex].position.w);
    lightDistance = length(lightDir);
    lightDir = normalize(lightDir);

        // This has a *considerable* performance uplift where GPU is a bottleneck
    if (lightDistance > getLight[lightIndex].attenuation.w * 2.0)
    {
        ambientOut = vec3(0.0);
        diffuseOut = vec3(0.0);
        return;
    }

    #ifdef ATTEN_FIX
        float illumination = clamp(1.0 / (getLight[lightIndex].attenuation.x * 0.1 + 0.01 * getLight[lightIndex].attenuation.y * lightDistance * lightDistance) - 0.054, 0.0, 1.0);
        illumination = clamp(illumination * illumination, 0.0, 1.0);
    #else
        float illumination = clamp(1.0 / (getLight[lightIndex].attenuation.x + getLight[lightIndex].attenuation.y * lightDistance + getLight[lightIndex].attenuation.z * lightDistance * lightDistance), 0.0, 1.0);
        illumination *= 1.0 - quickstep((lightDistance / (getLight[lightIndex].attenuation.w)) - 1.0);
    #endif

    ambientOut = ambient * getLight[lightIndex].ambient.xyz * illumination;
    diffuseOut = diffuse.xyz * getLight[lightIndex].diffuse.xyz * max(dot(viewNormal.xyz, lightDir), 0.0) * illumination;
}


#if PER_PIXEL_LIGHTING
vec3 doLighting(vec3 viewPos, vec3 viewNormal, vec4 vertexColor, float shadowing)
#else
vec3 doLighting(vec3 viewPos, vec3 viewNormal, vec4 vertexColor)
#endif
{
    vec4 diffuse;
    vec3 ambient;

    if (colorMode == ColorMode_AmbientAndDiffuse)
    {
        diffuse = vertexColor;
        ambient = vertexColor.xyz;
    }
    else if (colorMode == ColorMode_Diffuse)
    {
        diffuse = vertexColor;
        ambient = gl_FrontMaterial.ambient.xyz;
    }
    else if (colorMode == ColorMode_Ambient)
    {
        diffuse = gl_FrontMaterial.diffuse;
        ambient = vertexColor.xyz;
    }
    else
    {
        diffuse = gl_FrontMaterial.diffuse;
        ambient = gl_FrontMaterial.ambient.xyz;
    }
    vec4 lightResult = vec4(0.0, 0.0, 0.0, diffuse.a);

    vec3 diffuseLight, ambientLight;

    LightSun(ambientLight, diffuseLight, 0, viewPos, viewNormal, diffuse, ambient);

    float interiorb = 0.0;
#ifdef OBJECT
    if(isInterior)
    {
        interiorb = 1.0;
        ambientLight *= vec3(intsunlight);
        diffuseLight *= vec3(intsunlight);
    }
#endif

    lightResult.xyz += (diffuseLight + ambientLight);

    #if PER_PIXEL_LIGHTING
        lightResult.xyz += diffuseLight * shadowing - diffuseLight; // This light gets added a second time in the loop to fix Mesa users' slowdown, so we need to negate its contribution here.
    #endif

    for (int i=1; i <= PointLightCount; ++i)
    {
        diffuseLight = vec3(0.0);
        if(getLight[i].diffuse.x > 0.0)
            perLight(ambientLight, diffuseLight, i, viewPos, viewNormal, diffuse, ambient);

#ifdef OBJECT
        else if(isInterior)
            perNegativeLight(ambientLight, diffuseLight, i, viewPos, viewNormal, diffuse, ambient);
#endif

       if(diffuseLight != vec3(0.0))
           lightResult.xyz += ambientLight + diffuseLight;
    }

#ifdef LINEAR_LIGHTING
    vec3 ambientmapped = Remap(gl_LightModel.ambient.xyz * gl_LightModel.ambient.xyz, vec3(ambmin), vec3(1.0));
	  vec3 ambientcon = vec3(mix(gl_LightModel.ambient.xyz * gl_LightModel.ambient.xyz * aoutexp, ambientmapped * aintexp, interiorb));
	
	  float fres = dot(-viewNormal, normalize(viewPos.xyz));

    // skylight
    vec3 skylight = vec3(0.25,0.61,1.0);
	  vec3 overcast = vec3(0.5, 0.5, 0.52);
	  vec4 skyDir = vec4(0.0, 0.0, 1.0, 0.0);
	  skyDir = gl_ModelViewMatrix * skyDir;
	
  	skylight = skylight * skylight;
	  overcast = overcast * overcast;
	  float ambisky = length(clamp(4.0 * gl_LightModel.ambient.xyz - vec3(1.0), 0.0, 1.0));

    vec3 skyterm1 = mix(nightoc * overcast, dayoc * overcast, ambisky);
	  vec3 skyterm2 = daysky * skylight;
    vec3 skyterm3 = getLight[0].diffuse.xyz * getLight[0].diffuse.xyz * dayskysun;
	  skylight = 0.10 * mix(skyterm1, skyterm2 + skyterm3,  getLight[0].diffuse.x * getLight[0].diffuse.x);
	
	  ambientcon *= ambientcontribution * max(0.0, pow(1.0 - fres,2.0)) + mix(skylight, vec3(1.0), interiorb) * max(0.0, fres);
	
	  skylight *=  clamp((dot(viewNormal.xyz, skyDir.xyz) + 0.6) /((1.0 + 0.6) * (1.0 + 0.6)), 0.0 ,1.0);
    skylight = skylight * (1.0 - interiorb);
    vec3 noskylight = lightResult.xyz;

    lightResult.xyz += ambientcon;
	  lightResult.xyz += skylight;
	  lightResult.xyz *= vec3(vcoff) + vcexp * ambient * ambient;
#endif

    if (colorMode == ColorMode_Emission)
        lightResult.xyz += vertexColor.xyz;
    else
        lightResult.xyz += mix(emivnight, emivday, getLight[0].diffuse.x) * gl_FrontMaterial.emission.xyz;

    return lightResult.xyz;
}

vec3 getSpecular(vec3 viewNormal, vec3 viewDirection, float shininess, vec3 matSpec)
{
    vec3 sunDir = getLight[0].position.xyz;
    vec3 sunSpec = getLight[0].specular.xyz;

    vec3 lightDir = normalize(sunDir);
    float NdotL = dot(viewNormal, lightDir);
    if (NdotL <= 0.0)
        return vec3(0.0);
    vec3 halfVec = normalize(lightDir - viewDirection);
    float NdotH = dot(viewNormal, halfVec);
    return pow(max(NdotH, 0.0), max(1e-4, shininess)) * sunSpec * matSpec;
}