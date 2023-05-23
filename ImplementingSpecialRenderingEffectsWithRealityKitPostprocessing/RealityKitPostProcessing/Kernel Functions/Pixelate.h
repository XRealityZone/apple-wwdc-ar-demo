/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Defines a structure that can be used both in Metal and Swift through a
 bridging header.
*/

#include <simd/simd.h>

#ifndef Pixelate_h
#define Pixelate_h

/// Container for pixelate kernel parameters.
///
/// Because Metal is based on C++, defining a C++ struct in a
/// header and adding a bridging header to the project allows both Swift and Metal to use the same struct
/// definition. Using a C++ struct accessed by both Metal shaders and swift.
struct PixelateArguments
{
    uint32_t cellSizeWidth;
    uint32_t cellSizeHeight;
};
#endif /* Pixelate_h */
