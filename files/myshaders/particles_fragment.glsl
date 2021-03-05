#version 120

#define PARTICLE

#if @diffuseMap
uniform sampler2D diffuseMap;
varying vec2 diffuseMapUV;
#endif

centroid varying vec4 lighting;
varying float depth;

#include "helpsettings.glsl"
#include "fog.glsl"

vec3 SpecialContrast(vec3 x, float suncon) 
{
	vec3 contrasted = x*x*x*(x*(x*6.0 - 15.0) + 10.0);
	x.rgb = mix(x.rgb, contrasted, suncon);
	return x;
}

void main()
{
#if @diffuseMap
    gl_FragData[0] = texture2D(diffuseMap, diffuseMapUV);
#else
    gl_FragData[0] = vec4(1.0);
#endif

if(gl_FragData[0].a != 0.0)
{
    gl_FragData[0] *= lighting;

#ifdef LINEAR_LIGHTING
        gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/(2.2+(@gamma.0/1000.0)-1.0)));
        gl_FragData[0].xyz = SpecialContrast(gl_FragData[0].xyz, mix(connight, conday, gl_LightSource[0].diffuse.x));
#endif
}

    applyFog(false, depth);

#if (@gamma != 1000) && !defined(LINEAR_LIGHTING)
    gl_FragData[0].xyz = pow(gl_FragData[0].xyz, vec3(1.0/(@gamma.0/1000.0)));
#endif

    //gl_FragData[0] = vec4(1.0, 0.0, 0.0, 1.0);
}
