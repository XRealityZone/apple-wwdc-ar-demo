/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A Metal compute functions that implements visual effects for capture chess pieces.
*/

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

inline float mod(float x, float y)
{
    return x - ((int)(x / y)) * y;
}

float bounceInShape(float t, float height = 1.5)
{
    t = saturate(t);
    return max(sin(t * M_PI_F) * height, step(0.5,t));
}

[[visible]]
void capturedGeometry(realitykit::geometry_parameters params)
{
    const float progress = params.uniforms().custom_parameter()[0];
    
    constexpr int kScaleAxis = 1;
    constexpr int kTimeAxis = 0;
    
    auto geo = params.geometry();
    
    float timeOffset = 1 - progress;
    float geoOffset = geo.model_position()[kTimeAxis];
    float t = bounceInShape(timeOffset - geoOffset);
    
    float3 offset(0);
    offset[kScaleAxis] = -geo.model_position()[kScaleAxis] * (1.0 - t);
    
    geo.set_model_position_offset(offset);
    geo.set_custom_attribute(float4(t, 0, 0, 0));
}
