#version 120

varying vec2 uv;
varying float depth;

#define PER_PIXEL_LIGHTING (@normalMap || @forcePPL)

#include "helpsettings.glsl"
#include "vertexcolors.glsl"

#ifdef HEIGHT_FOG
varying vec3 fogH;
#endif

#if defined(UNDERWATER_DISTORTION) || defined(HEIGHT_FOG)
uniform mat4 osg_ViewMatrixInverse;
#endif

#ifdef UNDERWATER_DISTORTION
uniform float osg_SimulationTime;
#endif

uniform vec4 shaderSettings;

varying vec3 passViewPos;

varying vec3 passNormal;


#include "lighting_util.glsl"
centroid varying vec3 passLighting;

  #ifdef LINEAR_LIGHTING
    #include "linear_lighting.glsl"
  #else
    #include "lighting.glsl"
  #endif

void main(void)
{
    bool radialFog = (shaderSettings.y == 1.0 || shaderSettings.y == 3.0 || shaderSettings.y == 5.0 || shaderSettings.y == 7.0) ? true : false;
    bool clampLighting = (shaderSettings.y == 2.0 || shaderSettings.y == 3.0 || shaderSettings.y == 6.0 || shaderSettings.y == 7.0) ? true : false;
    bool PPL = (shaderSettings.y == 4.0 || shaderSettings.y == 5.0 || shaderSettings.y == 6.0 || shaderSettings.y == 7.0) ? true : false;

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

    vec4 viewPos = (gl_ModelViewMatrix * gl_Vertex);
    gl_ClipVertex = viewPos;

if(radialFog)
    depth = length(viewPos.xyz);
else
    depth = gl_Position.z;

    passColor = gl_Color;
    passViewPos = viewPos.xyz;

    passNormal = gl_Normal.xyz;

#ifdef HEIGHT_FOG
    fogH = (osg_ViewMatrixInverse * viewPos).xyz;
#endif
    uv = gl_MultiTexCoord0.xy;

#ifdef UNDERWATER_DISTORTION
if(osg_ViewMatrixInverse[3].z < -1.0)
{
    vec2 harmonics;
    vec4 wP = osg_ViewMatrixInverse * vec4(viewPos.xyz, 1.0);
    harmonics += vec2(sin(1.0*osg_SimulationTime + wP.xy / 1100.0));
    harmonics += vec2(cos(2.0*osg_SimulationTime + wP.xy / 750.0));
    harmonics += vec2(sin(3.0*osg_SimulationTime + wP.xy / 500.0));
    harmonics += vec2(sin(5.0*osg_SimulationTime + wP.xy / 200.0));
    gl_Position.xy += (depth * 0.003) * harmonics;
}
#endif


if (!PPL) {
    vec3 shadowDiffuseLighting;
    vec3 viewNormal = normalize((gl_NormalMatrix * gl_Normal).xyz);
#ifdef LINEAR_LIGHTING
    passLighting = doLighting(viewPos.xyz, viewNormal, gl_Color);
#else
    vec3 diffuseLight, ambientLight;
    doLighting(viewPos.xyz, viewNormal, diffuseLight, ambientLight, shadowDiffuseLighting, 1.0, false);
    passLighting = getDiffuseColor().xyz * diffuseLight + getAmbientColor().xyz * ambientLight + getEmissionColor().xyz;
#endif
    clampLightingResult(passLighting, clampLighting);
    shadowDiffuseLighting *= getDiffuseColor().xyz;
    passLighting += shadowDiffuseLighting;
}
}
