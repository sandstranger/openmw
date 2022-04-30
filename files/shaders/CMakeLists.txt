if (NOT DEFINED OPENMW_RESOURCES_ROOT)
    return()
endif()

# Copy resource files into the build directory
set(SDIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DDIR resources/shaders)
set(DDIRPBR resources/shaders/pbr)
set(DDIRMODIFIED resources/shaders/modified)

set(SHADER_FILES
    android/groundcover_vertex.glsl
    android/groundcover_fragment.glsl
    android/vtastek_water_vertex.glsl
    android/vtastek_water_fragment.glsl
    android/water_vertex.glsl
    android/water_fragment.glsl
    android/water_nm.png
    android/alpha.glsl
    android/depth.glsl
    android/objects_vertex.glsl
    android/objects_fragment.glsl
    android/terrain_vertex.glsl
    android/terrain_fragment.glsl
    android/particles_vertex.glsl
    android/particles_fragment.glsl
    android/lighting.glsl
    android/lighting_util.glsl
    android/parallax.glsl
    android/s360_fragment.glsl
    android/s360_vertex.glsl
    android/shadows_vertex.glsl
    android/shadows_fragment.glsl
    android/shadowcasting_vertex.glsl
    android/shadowcasting_fragment.glsl
    android/vertexcolors.glsl
    android/nv_default_vertex.glsl
    android/nv_default_fragment.glsl
    android/nv_nolighting_vertex.glsl
    android/nv_nolighting_fragment.glsl
    android/gui_vertex.glsl
    android/gui_fragment.glsl
    android/debug_vertex.glsl
    android/debug_fragment.glsl
    android/sky_vertex.glsl
    android/sky_fragment.glsl
    android/skypasses.glsl
    android/softparticles.glsl
)

set(MODIFIED_SHADER_FILES
    modified/fog.glsl
    modified/effects.glsl
    modified/helpsettings.glsl
    modified/groundcover_vertex.glsl
    modified/groundcover_fragment.glsl
    modified/water_vertex.glsl
    modified/water_fragment.glsl
    modified/vtastek_water_vertex.glsl
    modified/vtastek_water_fragment.glsl
    modified/water_nm.png
    modified/alpha.glsl
    modified/depth.glsl
    modified/tonemap.glsl
    modified/objects_vertex.glsl
    modified/objects_fragment.glsl
    modified/terrain_vertex.glsl
    modified/terrain_fragment.glsl
    modified/particles_vertex.glsl
    modified/particles_fragment.glsl
    modified/lighting.glsl
    modified/lighting_util.glsl
    modified/s360_fragment.glsl
    modified/s360_vertex.glsl
    modified/shadows_vertex.glsl
    modified/shadows_fragment.glsl
    modified/shadowcasting_vertex.glsl
    modified/shadowcasting_fragment.glsl
    modified/vertexcolors.glsl
    modified/nv_default_vertex.glsl
    modified/nv_default_fragment.glsl
    modified/nv_nolighting_vertex.glsl
    modified/nv_nolighting_fragment.glsl
    modified/gui_vertex.glsl
    modified/gui_fragment.glsl
    modified/debug_vertex.glsl
    modified/debug_fragment.glsl
    modified/sky_vertex.glsl
    modified/sky_fragment.glsl
    modified/skypasses.glsl
    modified/softparticles.glsl
)

copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_RESOURCES_ROOT} ${DDIR} "${SHADER_FILES}")
copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_RESOURCES_ROOT} ${DDIRMODIFIED} "${MODIFIED_SHADER_FILES}")

