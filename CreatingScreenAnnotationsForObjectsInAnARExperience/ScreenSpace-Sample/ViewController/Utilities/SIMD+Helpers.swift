/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SIMD convenience properties.
*/

import Foundation

extension SIMD4 {
    
    var xyz: SIMD3<Scalar> {
        return self[SIMD3(0, 1, 2)]
    }
    
}
