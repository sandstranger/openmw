#if !@ffpLighting
struct Sunlight
{
    vec4 diffuse;
    vec4 ambient;
    vec4 specular;
    vec4 direction;
};

#if @useUBO
layout(std140) uniform SunlightBuffer
{
    Sunlight Sun;
};
#else
uniform Sunlight Sun;
#endif
#endif