#version 120

#define PER_PIXEL_LIGHTING 0

#define GRASS

#include "helpsettings.glsl"

#if @diffuseMap
varying vec2 diffuseMapUV;
#endif

varying float depth;
#if !@radialFog
varying float linearDepth;
#endif

#ifdef HEIGHT_FOG
varying vec3 fogH;
#endif

#if @underwaterFog
varying vec3 passViewPos;
#endif

uniform int colorMode;
centroid varying vec4 lighting;
#ifdef LINEAR_LIGHTING
  #include "linear_lighting.glsl"
#else
  #include "lighting.glsl"
#endif

uniform mat4 osg_ViewMatrixInverse;
uniform float osg_SimulationTime;

uniform float windSpeed;
uniform vec3 playerPos;
attribute float originalCoords;

#ifdef STORM_MODE
uniform vec2 stormDir;
#endif

vec4 grassDisplacement(vec3 viewPos, vec4 vertex)
{
    float h = originalCoords;

    vec4 worldPos = osg_ViewMatrixInverse * vec4(viewPos, 1.0);

    vec2 WindVec = vec2(windSpeed);

    float v = length(WindVec);
    vec2 displace = vec2(2.0 * WindVec + 0.1);

    vec2 harmonics = vec2(0.0);

    harmonics.xy += vec2((1.0 - 0.10*v) * sin(1.0*osg_SimulationTime +  worldPos.xy / 1100.0));
    harmonics.xy += vec2((1.0 - 0.04*v) * cos(2.0*osg_SimulationTime +  worldPos.xy / 750.0));
    harmonics.xy += vec2((1.0 + 0.14*v) * sin(3.0*osg_SimulationTime +  worldPos.xy / 500.0));
    harmonics.xy += vec2((1.0 + 0.28*v) * sin(5.0*osg_SimulationTime  +  worldPos.xy / 200.0));

    float d = length(worldPos.xyz - playerPos);
    vec3 stomp = vec3(0.0);
    if(d < 150.0) stomp = (60.0 / d - 0.4) * (worldPos.xyz - playerPos);

    vec4 ret = vec4(0.0);
    ret.xy += clamp(0.02 * h, 0.0, 1.0) * (harmonics * displace + stomp.xy);

#ifdef STORM_MODE
    if(stormDir != vec2(0.0) && h > 0.0) {
        ret.xy += h*stormDir;
        ret.z -= length(ret.xy)/3.14;
        ret.z -= sin(osg_SimulationTime * min(h, 150.0) / 10.0) * length(stormDir);
     }
#endif

    return vertex + ret;
}

void main(void)
{
    vec4 viewPos = (gl_ModelViewMatrix * gl_Vertex);
    gl_Position = gl_ModelViewProjectionMatrix * grassDisplacement(viewPos.xyz, gl_Vertex);

    gl_ClipVertex = viewPos;
    depth = length(viewPos.xyz);

#if !@radialFog
    linearDepth = gl_Position.z;
#endif

#if @diffuseMap
    diffuseMapUV = (gl_TextureMatrix[@diffuseMapUV] * gl_MultiTexCoord@diffuseMapUV).xy;
#endif

    vec3 viewNormal = normalize((gl_NormalMatrix * gl_Normal).xyz);
    lighting = doLighting(viewPos.xyz, viewNormal, vec4(1.0));

#if @underwaterFog
    passViewPos = viewPos.xyz;
#endif

#ifdef HEIGHT_FOG
    fogH = (osg_ViewMatrixInverse * viewPos).xyz;
#endif

#ifdef UNDERWATER_DISTORTION
if(osg_ViewMatrixInverse[3].z < -1.0 && gl_LightSource[0].diffuse.x != 0.0)
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
}
