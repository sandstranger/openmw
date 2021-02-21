struct PointLight
{
    vec4 diffuse;
    vec4 ambient;
    vec4 position;
    vec4 attenuation;
};

uniform int PointLightCount;

layout(std140) uniform PointLightBuffer
{
    PointLight PointLights[@maxLights];
};

#include "sun.glsl"

void lightSun(out vec3 ambientOut, out vec3 diffuseOut, vec3 viewPos, vec3 viewNormal)
{
    vec3 lightDir = Sun.direction.xyz - viewPos * Sun.direction.w;
    float lightDistance = length(lightDir);
    lightDir = normalize(lightDir);
    float illumination = 1.0;

    ambientOut = Sun.ambient.xyz * illumination;

    float lambert = dot(viewNormal.xyz, lightDir) * illumination;
#ifndef GROUNDCOVER
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
    diffuseOut = Sun.diffuse.xyz * lambert;
}

void perLight(out vec3 ambientOut, out vec3 diffuseOut, int lightIndex, vec3 viewPos, vec3 viewNormal)
{
    vec3 lightDir = PointLights[lightIndex].position.xyz - viewPos * PointLights[lightIndex].position.w;

    float lightDistance = length(lightDir);
    lightDir = normalize(lightDir);
    
    float illumination = clamp(1.0 / (PointLights[lightIndex].attenuation.x + PointLights[lightIndex].attenuation.y * lightDistance + PointLights[lightIndex].attenuation.z * lightDistance * lightDistance), 0.0, 1.0);
    // vtasteks attenuation tweak
    //float illumination = clamp(1.0 / (PointLights[lightIndex].attenuation.x * 0.1 + 0.01 * PointLights[lightIndex].attenuation.y * lightDistance * lightDistance) - 0.054, 0.0, 1.0);
    //illumination = clamp(illumination * illumination, 0.0, 1.0);

    ambientOut = PointLights[lightIndex].ambient.xyz * illumination;

    float lambert = dot(viewNormal.xyz, lightDir) * illumination;
#ifndef GROUNDCOVER
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
    diffuseOut = PointLights[lightIndex].diffuse.xyz * lambert;
}

#if PER_PIXEL_LIGHTING
void doLighting(vec3 viewPos, vec3 viewNormal, float shadowing, out vec3 diffuseLight, out vec3 ambientLight)
#else
void doLighting(vec3 viewPos, vec3 viewNormal, out vec3 diffuseLight, out vec3 ambientLight, out vec3 shadowDiffuse)
#endif
{
    vec3 ambientOut, diffuseOut;
    // This light gets added a second time in the loop to fix Mesa users' slowdown, so we need to negate its contribution here.
    lightSun(ambientOut, diffuseOut, viewPos, viewNormal); // TODO: I don't understand what this is for, still needed?

#if PER_PIXEL_LIGHTING
    diffuseLight = diffuseOut * shadowing - diffuseOut;
#else
    shadowDiffuse = diffuseOut;
    diffuseLight = -diffuseOut;
#endif
    ambientLight = gl_LightModel.ambient.xyz;
    
    lightSun(ambientOut, diffuseOut, viewPos, viewNormal);
    ambientLight += ambientOut;
    diffuseLight += diffuseOut;

    for (int i=0; i<PointLightCount; ++i)
    {
        perLight(ambientOut, diffuseOut, i, viewPos, viewNormal);
        ambientLight += ambientOut;
        diffuseLight += diffuseOut;
    }
}

vec3 getSpecular(vec3 viewNormal, vec3 viewDirection, float shininess, vec3 matSpec)
{
    vec3 lightDir = normalize(Sun.direction.xyz);
    float NdotL = dot(viewNormal, lightDir);
    if (NdotL <= 0.0)
        return vec3(0.0);
    vec3 halfVec = normalize(lightDir - viewDirection);
    float NdotH = dot(viewNormal, halfVec);
    return pow(max(NdotH, 0.0), max(1e-4, shininess)) * Sun.specular.xyz * matSpec;
}
