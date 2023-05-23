/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Type extensions used in the project.
*/

import Foundation
import ARKit

// MARK: - Collection extensions

extension Array where Iterator.Element == SIMD3<Float> {
    var average: SIMD3<Float>? {
        guard !self.isEmpty else {
            return nil
        }
        
        let sum = self.reduce(SIMD3<Float>(repeating: 0)) { current, next in
            return current + next
        }
        return sum / Float(self.count)
    }
}

extension RangeReplaceableCollection {
    mutating func keepLast(_ elementsToKeep: Int) {
        if count > elementsToKeep {
            self.removeFirst(count - elementsToKeep)
        }
    }
}

// MARK: - float4x4 extensions

extension float4x4 {
    // Treats matrix as a (right-hand column-major convention) transform matrix
    // and factors out the translation component of the transform.
    var translation: SIMD3<Float> {
        let translation = self.columns.3
        return SIMD3<Float>(translation.x, translation.y, translation.z)
    }
}
