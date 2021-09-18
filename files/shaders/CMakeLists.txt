if (NOT DEFINED OPENMW_SHADERS_ROOT)
    return()
endif()

# Copy resource files into the build directory
set(SDIR ${CMAKE_CURRENT_SOURCE_DIR})
set(DDIR resources/shaders)
set(DDIRPBR resources/shaders/pbr)
set(DDIRMODIFIED resources/shaders/modified)
set(DDIRMODIFIEDTONEMAP resources/shaders/modified/glsl-tone-map-master)

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
    gui_vertex.glsl
    gui_fragment.glsl
    debug_vertex.glsl
    debug_fragment.glsl
)

set(SHADER_FILES_PBR
    pbr/helper_util.glsl
    pbr/groundcover_vertex.glsl
    pbr/groundcover_fragment.glsl
    pbr/water_vertex.glsl
    pbr/water_fragment.glsl
    pbr/water_nm.png
    pbr/alpha.glsl
    pbr/depth.glsl
    pbr/objects_vertex.glsl
    pbr/objects_fragment.glsl
    pbr/terrain_vertex.glsl
    pbr/terrain_fragment.glsl
    pbr/lighting.glsl
    pbr/lighting_util.glsl
    pbr/parallax.glsl
    pbr/s360_fragment.glsl
    pbr/s360_vertex.glsl
    pbr/shadows_vertex.glsl
    pbr/shadows_fragment.glsl
    pbr/shadowcasting_vertex.glsl
    pbr/shadowcasting_fragment.glsl
    pbr/vertexcolors.glsl
    pbr/nv_default_vertex.glsl
    pbr/nv_default_fragment.glsl
    pbr/nv_nolighting_vertex.glsl
    pbr/nv_nolighting_fragment.glsl
    pbr/gui_vertex.glsl
    pbr/gui_fragment.glsl
    pbr/debug_vertex.glsl
    pbr/debug_fragment.glsl
)

set(MODIFIED_SHADER_FILES
    modified/fog.glsl
    modified/effects.glsl
    modified/linear_lighting.glsl
    modified/lightsettings.glsl
    modified/helpsettings.glsl
    modified/groundcover_vertex.glsl
    modified/groundcover_fragment.glsl
    modified/water_vertex.glsl
    modified/water_fragment.glsl
    modified/water_nm.png
    modified/alpha.glsl
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
)

set(MODIFIED_SHADER_TONEMAP_FILES
    modified/glsl-tone-map-master/aces.glsl
    modified/glsl-tone-map-master/filmic.glsl
    modified/glsl-tone-map-master/lottes.glsl
    modified/glsl-tone-map-master/none.glsl
    modified/glsl-tone-map-master/reinhard.glsl
    modified/glsl-tone-map-master/reinhard2.glsl
    modified/glsl-tone-map-master/uchimura.glsl
    modified/glsl-tone-map-master/uncharted2.glsl
    modified/glsl-tone-map-master/unreal.glsl
    modified/glsl-tone-map-master/vtastek.glsl

)

copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_SHADERS_ROOT} ${DDIR} "${SHADER_FILES}")
copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_SHADERS_ROOT} ${DDIRPBR} "${SHADER_FILES_PBR}")
copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_SHADERS_ROOT} ${DDIRMODIFIED} "${MODIFIED_SHADER_FILES}")
copy_all_resource_files(${CMAKE_CURRENT_SOURCE_DIR} ${OPENMW_SHADERS_ROOT} ${DDIRMODIFIEDTONEMAP} "${MODIFIED_SHADER_TONEMAP_FILES}")
