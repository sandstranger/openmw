if (NOT DEFINED OPENMW_SHADERS_ROOT)
    return()
endif()

# Copy resource files into the build directory
set(SDIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DDIRRELATIVE resources/shaders)

set(SHADER_FILES
    ../myshaders/fog.glsl
    ../myshaders/effects.glsl
    ../myshaders/linear_lighting.glsl
    ../myshaders/lightsettings.glsl
    ../myshaders/helpsettings.glsl
    ../myshaders/groundcover_vertex.glsl
    ../myshaders/groundcover_fragment.glsl
    ../myshaders/water_vertex.glsl
    ../myshaders/water_fragment.glsl
    ../myshaders/water_nm.png
    ../myshaders/alpha.glsl
    ../myshaders/objects_vertex.glsl
    ../myshaders/objects_fragment.glsl
    ../myshaders/terrain_vertex.glsl
    ../myshaders/terrain_fragment.glsl
    ../myshaders/lighting.glsl
    ../myshaders/lighting_util.glsl
    ../myshaders/s360_fragment.glsl
    ../myshaders/s360_vertex.glsl
    ../myshaders/shadows_vertex.glsl
    ../myshaders/shadows_fragment.glsl
    ../myshaders/shadowcasting_vertex.glsl
    ../myshaders/shadowcasting_fragment.glsl
    ../myshaders/vertexcolors.glsl
    ../myshaders/nv_default_vertex.glsl
    ../myshaders/nv_default_fragment.glsl
    ../myshaders/nv_nolighting_vertex.glsl
    ../myshaders/nv_nolighting_fragment.glsl
)

copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_SHADERS_ROOT} ${DDIRRELATIVE} "${SHADER_FILES}")
