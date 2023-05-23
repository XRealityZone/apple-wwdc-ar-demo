/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A representation of a ray in a form that you can easily serialize for sending over a network.
*/
///- Tag: Ray
struct Ray: Codable {
    let direction: SIMD3<Float>
    let origin: SIMD3<Float>
}
