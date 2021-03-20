#define MAX_LIGHTS 8

void perLight(out vec3 ambientOut, out vec3 diffuseOut, int lightIndex, vec3 viewPos, vec3 viewNormal)
{
    vec3 lightDir = gl_LightSource[lightIndex].position.xyz - viewPos * gl_LightSource[lightIndex].position.w;
    float lightDistance = length(lightDir);
    lightDir = normalize(lightDir);
    float illumination = clamp(1.0 / (gl_LightSource[lightIndex].constantAttenuation + gl_LightSource[lightIndex].linearAttenuation * lightDistance + gl_LightSource[lightIndex].quadraticAttenuation * lightDistance * lightDistance), 0.0, 1.0);

    ambientOut = gl_LightSource[lightIndex].ambient.xyz * illumination;

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
    diffuseOut = gl_LightSource[lightIndex].diffuse.xyz * lambert;
}

#if PER_PIXEL_LIGHTING
void doLighting(vec3 viewPos, vec3 viewNormal, float shadowing, out vec3 diffuseLight, out vec3 ambientLight)
#else
void doLighting(vec3 viewPos, vec3 viewNormal, out vec3 diffuseLight, out vec3 ambientLight, out vec3 shadowDiffuse)
#endif
{
    vec3 ambientOut, diffuseOut;
    // This light gets added a second time in the loop to fix Mesa users' slowdown, so we need to negate its contribution here.
    perLight(ambientOut, diffuseOut, 0, viewPos, viewNormal);
#if PER_PIXEL_LIGHTING
    diffuseLight = diffuseOut * shadowing - diffuseOut;
#else
    shadowDiffuse = diffuseOut;
    diffuseLight = -diffuseOut;
#endif

    ambientLight = gl_LightModel.ambient.xyz;
    for (int i=0; i<MAX_LIGHTS; ++i)
    {
        perLight(ambientOut, diffuseOut, i, viewPos, viewNormal);
        ambientLight += ambientOut;
        diffuseLight += diffuseOut;
    }
}