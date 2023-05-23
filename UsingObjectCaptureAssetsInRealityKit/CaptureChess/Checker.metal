/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A Metal compute function that highlights possible moves for the selected chess piece.
*/
#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

void checkerSurface(realitykit::surface_parameters params, float amplitude, bool isBlack = false)
{
    bool isPossibleMove = params.uniforms().custom_parameter()[0];
    
    half3 color;
    float roughness, specular;
    if (isBlack) {
        color = half3(0.05, 0.05, 0.05);
        roughness = 0.7;
        specular = 0.5;
    }
    else {
        color = half3(0.92, 0.92, 0.92);
        roughness = 0.1;
        specular = 0.8;
    }
    params.surface().set_base_color(color);
    params.surface().set_roughness(roughness);
    params.surface().set_specular(specular);
    
    if (isPossibleMove) {
        const float a = amplitude * sin(params.uniforms().time() * M_PI_F) + amplitude;
        params.surface().set_emissive_color(half3(a));
        if (isBlack) {
            color = half3(min(max(a, 0.05), 0.92));
            params.surface().set_base_color(color);
        }
    }
}

[[visible]]
void whiteCheckerSurface(realitykit::surface_parameters params)
{
    checkerSurface(params, 0.5);
}

[[visible]]
void blackCheckerSurface(realitykit::surface_parameters params)
{
    checkerSurface(params, 0.5, true);
}
