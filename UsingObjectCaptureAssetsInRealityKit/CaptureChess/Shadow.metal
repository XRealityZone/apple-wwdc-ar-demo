/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A Metal compute function that draws shadows.
*/

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

float smoothrect(float2 uv, float s)
{
    return smoothstep(0, s, uv.x) * (1.0 - smoothstep(1 - s, 1, uv.x)) *
        smoothstep(0, s, uv.y) * (1.0 - smoothstep(1 - s, 1, uv.y));
}

[[visible]]
void shadowSurface(realitykit::surface_parameters params)
{
    float3 position = params.geometry().model_position();
    
    if (position.y < 0.49) {
        discard_fragment();
    }
    
    half3 shadowColor = half3(0, 0, 0);
    params.surface().set_base_color(shadowColor);
    
    const float2 uv = params.geometry().uv0();
    
    const float progress = params.uniforms().custom_parameter()[0];
    
    const float phi = smoothrect(uv, 0.3);
    params.surface().set_opacity(phi * 0.5 * progress);
}
