/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility extensions for SIMD types.
*/

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        get { self[SIMD3(0, 1, 2)] }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
}

extension simd_float4x4 {
    init(_ matrix: Matrix) {
        self.init(matrix.col0, matrix.col1, matrix.col2, matrix.col3)
    }
}
