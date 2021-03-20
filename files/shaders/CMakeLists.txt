if (NOT DEFINED OPENMW_SHADERS_ROOT)
    return()
endif()

# Copy resource files into the build directory
set(SDIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DDIRRELATIVE resources/shaders)

set(SHADER_FILES
    #groundcover_vertex.glsl
    #groundcover_fragment.glsl
    #water_vertex.glsl
    #water_fragment.glsl
    #water_nm.png
    #alpha.glsl
    #objects_vertex.glsl
    #objects_fragment.glsl
    #terrain_vertex.glsl
    #terrain_fragment.glsl
    #lighting.glsl
    #parallax.glsl
    #s360_fragment.glsl
    #s360_vertex.glsl
    #shadows_vertex.glsl
    #shadows_fragment.glsl
    #shadowcasting_vertex.glsl
    #shadowcasting_fragment.glsl
    #vertexcolors.glsl

    ../myshaders/groundcover_vertex.glsl
    ../myshaders/groundcover_fragment.glsl
    ../myshaders/water_vertex.glsl
    ../myshaders/water_fragment.glsl
    ../myshaders/water_nm.png
    ../myshaders/objects_vertex.glsl
    ../myshaders/objects_fragment.glsl
    ../myshaders/terrain_vertex.glsl
    ../myshaders/terrain_fragment.glsl
    ../myshaders/s360_fragment.glsl
    ../myshaders/s360_vertex.glsl
    ../myshaders/shadowcasting_vertex.glsl
    ../myshaders/shadowcasting_fragment.glsl
    ../myshaders/effects.glsl
    ../myshaders/fog.glsl
    ../myshaders/lighting.glsl
    ../myshaders/linear_lighting.glsl
    ../myshaders/lightsettings.glsl
    ../myshaders/helpsettings.glsl
    ../myshaders/particles_vertex.glsl
    ../myshaders/particles_fragment.glsl
    ../myshaders/vertexcolors.glsl
    ../myshaders/alpha.glsl
)

copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_SHADERS_ROOT} ${DDIRRELATIVE} "${SHADER_FILES}")
