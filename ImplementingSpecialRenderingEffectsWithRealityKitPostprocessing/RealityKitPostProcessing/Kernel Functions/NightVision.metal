/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal postprocessing kernel to create a night vision effect.
*/

#include <metal_stdlib>
#include "PostProcessCommon.h"
#include "NightVision.h"

using namespace metal;

/// A very simple PNRG that's good enough to generate static noise for the night vision effect.
half random(uint32_t seed)
{
    seed = seed * 57 * 241;
    seed = (seed << 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 5959 + 935892) + 135095923) & 235982359) / 107355924.0f) + 1.0f) / 2.0f;
}

/// Implement a night vision effect by combining multiple effects, including a vignette, scanlines, noise, and a green tint.
[[kernel]]
void postProcessNightVision(uint2 gid [[thread_position_in_grid]],
                            texture2d<half, access::read> inColor [[texture(0)]],
                            texture2d<half, access::write> outColor [[texture(1)]],
                            constant NightVisionArguments *args [[buffer(0)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (!(gid.x < inColor.get_width() && gid.y < inColor.get_height())) {
        return;
    }
    
    const half luminanceThreshold = 0.2;
    const half4 amplification = 4.0;
    half4 color = inColor.read(gid);
    
    // Scanlines
    half yPosition = half(gid.y) / 3.0;
    if (int(yPosition)%2 == 0) {
        color /= 5.0;
    } else {
        // Green Tint
        half luminance = dot(color.rgb, kLuminance);
        if (luminance < luminanceThreshold)
            color *= amplification;
        
        half3 visionColor = half3(0.08, 0.95, 0.1);
        color.rgb = (color.rgb + (0.2)) * visionColor;
    }
    
    // Vignette
    half2 gidAsHalf2 = half2(gid);
    half2 textureSize = half2(inColor.get_width(), inColor.get_height());
    half2 fraction = gidAsHalf2 / textureSize;
    
    half xFade = sin(fraction.x * M_PI_H);
    half yFade = sin(fraction.y * M_PI_H);
    half fade = xFade * yFade * yFade;
    
    color.rgb *= half3(fade);
    
    // Noise
    color.rgb *= random(gid.x * gid.y * args->seed);
    outColor.write(color, gid);
}
