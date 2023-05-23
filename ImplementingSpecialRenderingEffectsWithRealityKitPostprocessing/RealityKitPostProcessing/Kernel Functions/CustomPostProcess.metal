/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal postprocessing kernels.
*/

#include <metal_stdlib>
#include "PostProcessCommon.h"
using namespace metal;

/// Converts a rendered framebuffer to grayscale.
[[kernel]]
void postProcessGreyScale(uint2 gid [[thread_position_in_grid]],
                          texture2d<half, access::read> inColor [[texture(0)]],
                          texture2d<half, access::write> outColor [[texture(1)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (gid.x >= inColor.get_width() || gid.y >= inColor.get_height()) {
        return;
    }
    
    half4 color = inColor.read(gid);
    half luminance = dot(color.rgb, kLuminance);
    half4 grayscale = half4(half3(luminance), color.a);
    outColor.write(grayscale, gid);
}

/// Inverts the color of a rendered RealityKit framebuffer.
[[kernel]]
void postProcessInvert(uint2 gid [[thread_position_in_grid]],
                       texture2d<half, access::read> inColor [[texture(0)]],
                       texture2d<half, access::write> outColor [[texture(1)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (gid.x >= inColor.get_width() || gid.y >= inColor.get_height()) {
        return;
    }
    
    outColor.write(1.0 - inColor.read(gid), gid);
}

/// Implements a vignette effect on a rendered RealityKit framebuffer.
[[kernel]]
void postProcessVignette (uint2 gid [[thread_position_in_grid]],
                          texture2d<half, access::read> inColor [[texture(0)]],
                          texture2d<half, access::write> outColor [[texture(1)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (gid.x >= inColor.get_width() || gid.y >= inColor.get_height()) {
        return;
    }
    
    half2 gidAsHalf2 = half2(gid);
    half4 color = inColor.read(gid);
    half2 textureSize = half2(inColor.get_width(), inColor.get_height());
    
    half2 fraction = gidAsHalf2 / textureSize;
    
    half xFade = sin(fraction.x * M_PI_H);
    half yFade = sin(fraction.y * M_PI_H);
    half fade = xFade * xFade * yFade * yFade * yFade;
    
    color.rgb *= half3(fade);
    outColor.write(color, gid);
}

/// Implements a 5-tone posterize effect on a rendered RealityKit framebuffer.
[[kernel]]
void postProcessPosterize(uint2 gid [[thread_position_in_grid]],
                          texture2d<half, access::read> inColor [[texture(0)]],
                          texture2d<half, access::write> outColor [[texture(1)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (gid.x >= inColor.get_width() || gid.y >= inColor.get_height()) {
        return;
    }
    
    const half gamma = 0.5;
    const half numberOfColors = 5.0;
    half4 color = inColor.read(gid);
    color = pow(color, half4(gamma));
    color = color * numberOfColors;
    color = floor(color);
    color = color / numberOfColors;
    color = pow(color, half4(1.0/gamma));
    color.w = inColor.read(gid).w;
    outColor.write(color, gid);
}

[[kernel]]
void postProcessScanlines(uint2 gid [[thread_position_in_grid]],
                          texture2d<half, access::read> inColor [[texture(0)]],
                          texture2d<half, access::write> outColor [[texture(1)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (!(gid.x < inColor.get_width() && gid.y < inColor.get_height())) {
        return;
    }
    
    half4 color = inColor.read(gid);
    half yPosition = half(gid.y) / 3.0;
    if (int(yPosition)%2 == 0) {
        color /= 3.0;
    }
    outColor.write(color, gid);
}

/// Converts a depth mask to an alpha mask. Depth-masked Core Image postprocessing effects uses this kernel.
[[kernel]]
void postProcessDepthToAlpha(uint2 gid [[thread_position_in_grid]],
                             texture2d<half, access::read> inColor [[texture(0)]],
                             texture2d<float, access::read> inDepth [[texture(1)]],
                             texture2d<half, access::write> outAlpha [[texture(2)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (!(gid.x < inColor.get_width() && gid.y < inColor.get_height())) {
        return;
    }
    
    float depth = inDepth.read(gid)[0];
    
    if (depth > FLT_EPSILON * 10) {
        outAlpha.write(1.0, gid);
    } else {
        outAlpha.write(0.0, gid);
    }
}
