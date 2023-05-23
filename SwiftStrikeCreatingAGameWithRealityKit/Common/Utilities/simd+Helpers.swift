/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions for SIMD vector and matrix types.
*/

import RealityKit

extension FloatingPoint {

    func clamped(lowerBound: Self, upperBound: Self) -> Self {
        return min(max(self, lowerBound), upperBound)
    }

}

extension float4x4 {

    var scale: SIMD3<Float> {
        return SIMD3<Float>(length(columns.0), length(columns.1), length(columns.2))
    }

    init(scale factor: Float) {
        self.init(scale: SIMD3<Float>(repeating: factor))
    }
    init(scale vector: SIMD3<Float>) {
        self.init(SIMD4<Float>(vector.x, 0, 0, 0),
                  SIMD4<Float>(0, vector.y, 0, 0),
                  SIMD4<Float>(0, 0, vector.z, 0),
                  SIMD4<Float>(0, 0, 0, 1))
    }

    static let identity = matrix_identity_float4x4

    init(translation: SIMD3<Float>) {
        self.init(columns: (SIMD4<Float>(1, 0, 0, 0),
                            SIMD4<Float>(0, 1, 0, 0),
                            SIMD4<Float>(0, 0, 1, 0),
                            SIMD4<Float>(translation.x, translation.y, translation.z, 1)))
    }

    var translation: SIMD3<Float> {
        get {
            return columns.3.xyz
        }
        set {
            columns.3.xyz = newValue
        }
    }

}

func removeScale(_ matrix: float4x4) -> float4x4 {
    var normalized = matrix
    normalized.columns.0 = simd.normalize(normalized.columns.0)
    normalized.columns.1 = simd.normalize(normalized.columns.1)
    normalized.columns.2 = simd.normalize(normalized.columns.2)
    return normalized
}

extension SIMD4 where Scalar == Float {

    init(_ xyz: SIMD3<Float>, _ w: Float) {
        self.init(xyz.x, xyz.y, xyz.z, w)
    }

    var xyz: SIMD3<Float> {
        get { return SIMD3<Float>(x: x, y: y, z: z) }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
}

extension float4x4 {

    var rotationAboutY: Float {
        let floatEpsilon: Float = 1e-7
        let rotation: Float
        if abs(columns.2.y) >= (1.0 - floatEpsilon) {
            rotation = 0.0
        } else {
            rotation = atan2(columns.2.x, columns.2.z)
        }
        return rotation
    }

}

func eulerAnglesFromMatrix(matrix: float4x4) -> SIMD3<Float> {
    var angles = SIMD3<Float>()
    let floatEpsilon: Float = 1e-7
    if matrix.columns.2.y >= 1.0 - floatEpsilon {
        angles.x = -Float.pi / 2
        angles.y = 0
        angles.z = atan2(-matrix.columns.0.z, -matrix.columns.1.z)
    } else if matrix.columns.2.y <= -1.0 + floatEpsilon {
        angles.x = -Float.pi / 2
        angles.y = 0
        angles.z = atan2(matrix.columns.0.z, matrix.columns.1.z)
    } else {
        angles.x = asin(-matrix.columns.2.y)
        angles.y = atan2(matrix.columns.2.x, matrix.columns.2.z)
        angles.z = atan2(matrix.columns.0.y, matrix.columns.1.y)
    }
    return angles
}

extension simd_quatf {
    static let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
}
