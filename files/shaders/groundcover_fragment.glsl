#version 120

#define GRASS

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

#include "helpsettings.glsl"

varying float depth;

#if !@radialFog
varying float linearDepth;
#endif

#if @underwaterFog
uniform mat4 osg_ViewMatrixInverse;
varying vec3 passViewPos;
#endif

#ifdef ANIMATED_HEIGHT_FOG
uniform float osg_SimulationTime;
#endif

centroid varying vec4 lighting;

#include "effects.glsl"
#include "fog.glsl"

float calc_coverage(float a, float alpha_ref, float falloff_rate)
{
    return clamp(falloff_rate * (a - alpha_ref) + alpha_ref, 0.0, 1.0);
}

void main()
{
#if @diffuseMap
    gl_FragData[0] = texture2D(diffuseMap, diffuseMapUV);
#else
    gl_FragData[0] = vec4(1.0);
#endif

gl_FragData[0].a = calc_coverage(gl_FragData[0].a, 128.0/255.0, 4.0);

    if (depth > @groundcoverFadeStart)
        gl_FragData[0].a *= 1.0-smoothstep(@groundcoverFadeStart, @groundcoverFadeEnd, depth);

if(gl_FragData[0].a != 0.0)
{
#ifdef LINEAR_LIGHTING
    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(2.2));
#endif

    gl_FragData[0] *= lighting;

#ifdef LINEAR_LIGHTING
        gl_FragData[0].xyz = Uncharted2ToneMapping(gl_FragData[0].xyz);
        gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/(2.2+(@gamma.0/1000.0)-1.0)));
        gl_FragData[0].xyz = SpecialContrast(gl_FragData[0].xyz, mix(connight, conday, gl_LightSource[0].diffuse.x));
#endif

}
    bool isUnderwater = false;
#if @underwaterFog
    isUnderwater = (osg_ViewMatrixInverse * vec4(passViewPos, 1.0)).z < -1.0 && osg_ViewMatrixInverse[3].z > -1.0 && gl_LightSource[0].diffuse.x != 0.0;
#endif

#if !@radialFog
    applyFog(isUnderwater, linearDepth);
#else
    applyFog(isUnderwater, depth);
#endif

#if (@gamma != 1000) && !defined(LINEAR_LIGHTING)
    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/(@gamma.0/1000.0)));
#endif

}
