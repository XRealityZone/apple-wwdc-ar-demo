/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions on system types.
*/

import Foundation
import ARKit

// MARK: - CGPoint extensions

extension CGPoint {
    /// Extracts the screen space point from a vector returned by SCNView.projectPoint(_:).
    init(_ vector: SCNVector3) {
        self.init(x: CGFloat(vector.x), y: CGFloat(vector.y))
    }
}

// MARK: - ARSCNView extensions

extension ARSCNView {
    
    func smartHitTest(_ point: CGPoint) -> ARHitTestResult? {
        
        // Perform the hit test.
        let results = hitTest(point, types: [.existingPlaneUsingGeometry])
        
        // 1. Check for a result on an existing plane using geometry.
        if let existingPlaneUsingGeometryResult = results.first(where: { $0.type == .existingPlaneUsingGeometry }) {
            return existingPlaneUsingGeometryResult
        }
        
        // 2. Check for a result on an existing plane, assuming its dimensions are infinite.
        let infinitePlaneResults = hitTest(point, types: .existingPlane)
        
        if let infinitePlaneResult = infinitePlaneResults.first {
            return infinitePlaneResult
        }
        
        // 3. As a final fallback, check for a result on estimated planes.
        return results.first(where: { $0.type == .estimatedHorizontalPlane })
    }
    
}

extension SCNNode {
    var extents: float3 {
        let (min, max) = boundingBox
        return float3(max) - float3(min)
    }
}

// MARK: - float4x4 extensions

extension float4x4 {
    init(translation vector: float3) {
        self.init(float4(1, 0, 0, 0),
                  float4(0, 1, 0, 0),
                  float4(0, 0, 1, 0),
                  float4(vector.x, vector.y, vector.z, 1))
    }
    
    var translation: float3 {
        let translation = columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}
