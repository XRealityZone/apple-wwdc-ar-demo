/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal functions that replicate the behavior of RealityKit's PhysicallyBasedMaterial.
*/

#ifndef CustomMaterialHelpers_h
#define CustomMaterialHelpers_h

#if defined(__METAL_VERSION__)

#include <RealityKit/RealityKit.h>
#include <RealityKit/RealityKitTextures.h>

#include <metal_stdlib>
#include <metal_types>

using namespace metal;

/// Use to sample a value from a texture.
constexpr sampler textureSampler(coord::normalized,
                                 address::repeat,
                                 filter::linear,
                                 mip_filter::linear);


/// Emulates the base color behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void baseColorPassThrough(realitykit::surface_parameters params);

/// Emulates the emissive color behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void emissiveColorPassThrough(realitykit::surface_parameters params);

/// Emulates the clearcoat and clearcoat roughness behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void clearcoatPassThrough(realitykit::surface_parameters params);

/// Emulates the roughness behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void roughnessPassThrough(realitykit::surface_parameters params);

/// Emulates the metallic behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void metallicPassThrough(realitykit::surface_parameters params);

/// Emulates the opacity behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void blendingPassThrough(realitykit::surface_parameters params);

/// Emulates the specular behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void specularPassThrough(realitykit::surface_parameters params);

/// Emulates the ambient occlusion behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void ambientOcclusionPassThrough(realitykit::surface_parameters params);

/// Emulates the normal behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void normalPassThrough(realitykit::surface_parameters params);

#endif /* #if defined(__METAL_VERSION__) */
#endif /* CustomMaterialHelpers_h */
