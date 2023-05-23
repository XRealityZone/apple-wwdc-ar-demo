/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A representation of a matrix in a form that you can easily serialize for sending over a network.
*/

struct Matrix: Codable {
    let col0: SIMD4<Float>
    let col1: SIMD4<Float>
    let col2: SIMD4<Float>
    let col3: SIMD4<Float>
    
    init() {
        col0 = .zero
        col1 = .zero
        col2 = .zero
        col3 = .zero
    }
    
    init(_ matrix: simd_float4x4) {
        let columns = matrix.columns
        col0 = columns.0
        col1 = columns.1
        col2 = columns.2
        col3 = columns.3
    }
}
