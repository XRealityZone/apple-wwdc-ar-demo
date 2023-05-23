/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal postprocessing kernel to create a pixelation effect.
*/

#include <metal_stdlib>
#include "PostProcessCommon.h"
#include "Pixelate.h"

using namespace metal;


[[kernel]]
void postProcessPixelate(uint2 gid [[thread_position_in_grid]],
                         texture2d<half, access::read> inColor [[texture(0)]],
                         texture2d<half, access::write> outColor [[texture(1)]],
                         constant PixelateArguments *args [[buffer(0)]])
{
    // Checks to make sure that the specified thread_position_in_grid value is
    // within the bounds of the framebuffer. This ensures that non-uniform size
    // threadgroups don't trigger an error. See
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes
    if (!(gid.x < inColor.get_width() && gid.y < inColor.get_height())) {
        return;
    }
    
    const uint2 cell_size = uint2(args->cellSizeWidth, args->cellSizeHeight);
    int width = inColor.get_width();
    int height = inColor.get_height();
    
    // This shader works by averaging the color value of pixels
    // by looping over the rows and columns in a cell. Because a nested
    // loop scales at O(xy), large cell sizes result in poor performance
    // if the code tries to average every pixel. To avoid that performance hit,
    // when a cell's width or height exceeds 10 pixels, this kernel samples
    // a subset of pixels at regular X and Y intervals and averages just
    // the sampled pixels. The result is nearly identical to sampling every
    // pixel, but is performant at any cell size.
    const int maxDimensionSamples = 10;
    int skipX = max(int(float(width) / maxDimensionSamples), 1);
    int skipY = max(int(float(height) / maxDimensionSamples), 1);
    
    
    uint2 startPosition = uint2((gid.x / cell_size.x) * cell_size.x,
                                (gid.y / cell_size.y) * cell_size.y);
    
    const int blockWidth = min(cell_size.x, width - startPosition.x);
    const int blockHeight = min(cell_size.y, height - startPosition.y);
    
    half4 color = half4(0.0);
    uint numberOfPixels = 0;
    
    
    for (int i = 0; i < blockHeight; i += skipX) {
        for (int j = 0; j < blockWidth; j+= skipY) {
            uint2 pixelPosition = uint2(startPosition.x + i, startPosition.y + j);
            color += inColor.read(pixelPosition);
            numberOfPixels++;
        }
    }
    outColor.write(color / numberOfPixels, gid);
}
