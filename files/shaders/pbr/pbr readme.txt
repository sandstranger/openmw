OpenMW PBR shaders v04 ALPHA
Now it can render non metals without ambient reflections.
metals and reflections after sky and post process shaders.

_spec as PBR map
means, delete all your old spec maps!!!

_spec channels
R: metalness 1.0(255) is metal
G: roughness
B: specular, 0.5 for 0.04(conversion is 0.16 * x^2)
A: AO (don't have black alpha)

Terrain doesn't have spec,
instead you can put roughness into alpha of _diffusespec
we assume there is no metal ground.

MGE XE conversion
_normals to _n
invert G channel(openmw is DX style, MGE is OpenGL style. Yes, I know!)

_parameters to _spec
invert R channel
make sure your alpha is not black as it is used for AO.
