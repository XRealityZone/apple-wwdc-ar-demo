/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Defines a structure that can be used both in Metal and Swift through a
 bridging header.
*/

#include <simd/simd.h>

#ifndef NightVision_h
#define NightVision_h

/// Container for pixelate night vision post process shader parameters.
///
/// Because Metal is based on C++, defining a C++ struct in a header and adding a bridging header to the
/// project allows both Swift and Metal to use the same struct definition. Using a C++ struct accessed by both
/// Metal shaders and swift.
struct NightVisionArguments
{
    uint32_t seed;
};

#endif /* NightVision_h */
