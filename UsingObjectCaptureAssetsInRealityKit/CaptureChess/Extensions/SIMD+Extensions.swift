/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Game-specific extensions on SIMD objects.
*/

import simd

extension simd_quatf {
    static let identity = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 0))
}

extension SIMD3 where Scalar == Float {
    static let i = SIMD3<Float>(1, 0, 0)
    static let j = SIMD3<Float>(0, 1, 0)
    static let k = SIMD3<Float>(0, 0, 1)
}
