#version 120

#define GRASS

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

#include "helpsettings.glsl"
#include "vertexcolors.glsl"

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

centroid varying vec3 passLighting;

#include "lighting_util.glsl"
#include "effects.glsl"
#include "fog.glsl"
#include "alpha.glsl"

void main()
{

if(@groundcoverFadeEnd != @groundcoverFadeStart)
    if (depth > @groundcoverFadeEnd)
        discard;

#if @diffuseMap
    gl_FragData[0] = texture2D(diffuseMap, diffuseMapUV);
#else
    gl_FragData[0] = vec4(1.0);
#endif

    if (depth > @groundcoverFadeStart)
        gl_FragData[0].a *= 1.0-smoothstep(@groundcoverFadeStart, @groundcoverFadeEnd, depth);

    alphaTest();

#ifdef LINEAR_LIGHTING
    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(2.2));
#endif

    gl_FragData[0].xyz *= passLighting;

#ifdef LINEAR_LIGHTING
        gl_FragData[0].xyz = Uncharted2ToneMapping(gl_FragData[0].xyz);
        gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/(2.2+(@gamma.0/1000.0)-1.0)));
        gl_FragData[0].xyz = SpecialContrast(gl_FragData[0].xyz, mix(connight, conday, lcalcDiffuse(0).x));
#endif

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
