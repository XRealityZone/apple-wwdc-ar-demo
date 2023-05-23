/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityKit UV texture coordinate utilities.
*/

#include "UVHelpers.h"
#include <RealityKit/RealityKit.h>
#include <metal_stdlib>
using namespace metal;

/// Retrieves the primary UV coordinates and flips the y-axis. UVs must be flipped like this when you load
/// entities from USDZ or `.reality` files.
float2 getFlippedUVs(realitykit::surface_parameters params)
{
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;
    return uv;
}

/// Rotates UV coordinates based on an angle (in radians) and a pivot point expressed in UV coordinate space.
float2 rotateUV(float2 uv, float2 pivot, float angle) {
    float sin_factor = sin(angle);
    float cos_factor = cos(angle);
    uv -= pivot;
    uv.x = uv.x * cos_factor - uv.y * sin_factor;
    uv.y = uv.x * sin_factor + uv.y * cos_factor;
    uv += pivot;
    return uv;
}

/// Rotates UV coordinates around the center of coordinate space.
float2 rotateUVCentered(float2 uv, float angle) {
    return rotateUV(uv, float2(0.5, 0.5), angle);
}
