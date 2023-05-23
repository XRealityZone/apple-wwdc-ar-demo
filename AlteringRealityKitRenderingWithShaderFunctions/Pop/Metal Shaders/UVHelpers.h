/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityKit UV texture coordinate utilities.
*/

#ifndef UVHelpers_h
#define UVHelpers_h

#if defined(__METAL_VERSION__)

#include <RealityKit/RealityKit.h>

#include <metal_stdlib>
#include <metal_types>

/// Retrieves the primary UV coordinates and flips the y-axis. UVs must be flipped like this when you load
/// entities from USDZ or `.reality` files.
float2 getFlippedUVs(realitykit::surface_parameters params);

/// Rotates UV coordinates based on an angle (in radians) and a pivot point expressed in UV coordinate
/// space.
float2 rotateUV(float2 uv, float2 pivot, float angle);

/// Rotates UV coordinates around the center of UV coordinate space.
float2 rotateUVCentered(float2 uv, float angle);

#endif /* #if defined(__METAL_VERSION__) */
#endif /* UVHelpers_h */
