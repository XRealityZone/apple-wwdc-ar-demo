/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Bridging header that gives Swift access to the NightVisionArguments Metal
 struct.
*/

// Because Metal is based on C++, and C++ is a superset of C, the same struct
// can be used from Metal and Swift if imported through a bridging header. This
// import makes the struct available to to the project's Swift code.

#import "NightVision.h"
#import "Pixelate.h"
