/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal compute functions that handle the visuals for selected game pieces.
*/

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

float remapInputToNewRange(float input, float inMin, float inMax, float outMin, float outMax) {
    if (input <= inMin) { return outMin; }
    if (input >= inMax) { return outMax; }
    if (inMin == inMax) { return outMin; }
    
    return (input - inMin) / (inMax - inMin) * (outMax - outMin) + outMin;
}

void selectionSurface(realitykit::surface_parameters params, half3 color)
{
    const float NOISEFREQUENCY = 0.6;
    const float NOISESPEED = 0.04;
    const float OPACITYSCALE = 0.75;
    
    const float2 uv = params.geometry().uv0();
    const float3 modelPosition = params.geometry().model_position();
    
    float2 shapeUV = uv;
    shapeUV.x *= NOISEFREQUENCY; // Shrink uv.x down to reduce noise frequency
    shapeUV.y = fmod(params.uniforms().time() * NOISESPEED, 1.0); // Move through noise at the given speed
    
    // Prepare for texture sampling.
    constexpr sampler textureSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
    auto tex = params.textures().base_color();
    
    // Sample the texture twice, once for shape, once for detail.
    half3 noiseColor = tex.sample(textureSampler, shapeUV).rgb;
    half3 detailColor = tex.sample(textureSampler, uv).rgb;
    
    // Remap the noise texture into a value range centered around 0.5.
    float noiseAmount = remapInputToNewRange(noiseColor.x, 0, 0.57, 0.4, 0.6);
    
    // Fit model position Y into noise lookup.
    float opacity = remapInputToNewRange(modelPosition.y, noiseAmount - 0.4, noiseAmount, 1, 0);
    
    // Add details at the top and solid at the bottom.
    opacity *= remapInputToNewRange(modelPosition.y, 0.1, 0.35, 1, detailColor.x);
    
    // Adjust by fresnel.
    float3 normal = normalize(params.geometry().normal());
    float3 I = -normalize(params.geometry().view_direction());
    
    float viewAngle = dot(normal, I);
    float fresnel = remapInputToNewRange(viewAngle, -0.2, 0.2, 1, 0);
    opacity *= fresnel;
    
    // Set the overall scale.
    opacity *= OPACITYSCALE;
    
    // Bump up some detail into the color.
    color += color * detailColor.x;
    
    params.surface().set_emissive_color(color);
    params.surface().set_opacity(opacity);
}

[[visible]]
void selectionSurfaceYellow(realitykit::surface_parameters params)
{
    const half3 yellowColor = half3(0.968411, 0.807722, 0.273454);
    selectionSurface(params, yellowColor);
}

[[visible]]
void selectionSurfaceBlue(realitykit::surface_parameters params)
{
    const half3 blueColor = half3(0.204652, 0.470958, 0.966113);
    selectionSurface(params, blueColor);
}
