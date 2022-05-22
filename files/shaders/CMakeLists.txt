if (NOT DEFINED OPENMW_RESOURCES_ROOT)
    return()
endif()

# Copy resource files into the build directory
set(SDIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DDIR resources/shaders)
set(DDIRPBR resources/shaders/pbr)
set(DDIRMODIFIED resources/shaders/modified)

set(SHADER_FILES
    groundcover_vertex.glsl
    groundcover_fragment.glsl
    water_vertex.glsl
    water_fragment.glsl
    water_nm.png
    alpha.glsl
    depth.glsl
    objects_vertex.glsl
    objects_fragment.glsl
    openmw_fragment.glsl
    openmw_fragment.h.glsl
    openmw_fragment_multiview.glsl
    openmw_vertex.glsl
    openmw_vertex.h.glsl
    openmw_vertex_multiview.glsl
    terrain_vertex.glsl
    terrain_fragment.glsl
    lighting.glsl
    lighting_util.glsl
    parallax.glsl
    s360_fragment.glsl
    s360_vertex.glsl
    shadows_vertex.glsl
    shadows_fragment.glsl
    shadowcasting_vertex.glsl
    shadowcasting_fragment.glsl
    vertexcolors.glsl
    nv_default_vertex.glsl
    nv_default_fragment.glsl
    nv_nolighting_vertex.glsl
    nv_nolighting_fragment.glsl
    blended_depth_postpass_vertex.glsl
    blended_depth_postpass_fragment.glsl
    gui_vertex.glsl
    gui_fragment.glsl
    debug_vertex.glsl
    debug_fragment.glsl
    sky_vertex.glsl
    sky_fragment.glsl
    skypasses.glsl
    softparticles.glsl
    hdr_fragment.glsl
    hdr_luminance_fragment.glsl
    fullscreen_tri_vertex.glsl
    fullscreen_tri_fragment.glsl
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
    blended_depth_postpass_vertex.glsl
    blended_depth_postpass_fragment.glsl
    modified/gui_vertex.glsl
    modified/gui_fragment.glsl
    modified/debug_vertex.glsl
    modified/debug_fragment.glsl
    modified/sky_vertex.glsl
    modified/sky_fragment.glsl
    modified/skypasses.glsl
    modified/softparticles.glsl
    hdr_luminance_fragment.glsl
    fullscreen_tri_vertex.glsl
    fullscreen_tri_fragment.glsl
)

copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_RESOURCES_ROOT} ${DDIR} "${SHADER_FILES}")
copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_RESOURCES_ROOT} ${DDIRMODIFIED} "${MODIFIED_SHADER_FILES}")

