/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A geometry modifier that scales an entity along its vertex normals.
*/


#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

/// Scales the entity along its vertex normals. The amount of scaling is based on a value contained in the first
/// component of the material's custom vector.
[[visible]]
void ExpandGeometryModifier(realitykit::geometry_parameters params)
{
    // Retrieve the progress value from the material.
    auto uniforms = params.uniforms();
    float progress = uniforms.custom_parameter()[0];
    
    // If the progress value is 0.0 or less, the entity isn't animating, so
    // there's no work to do.
    if (progress <= 0.0) {
        return;
    }
    
    // Get the current vertex's normal vector.
    auto vertexNormal = params.geometry().normal();
    
    // Offset the vertex along the normal. The distance is based on the progress
    // value.
    params.geometry().set_model_position_offset(vertexNormal * progress * 3.0);
    
}
