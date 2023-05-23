/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SceneKit node wrapper that estimates an object's final placement
*/

import Foundation
import ARKit

class PreviewNode: SCNNode {
    
    /// Saved positions that help smooth the movement of the preview
    var lastPositionOnPlane: SIMD3<Float>?
    var lastPosition: SIMD3<Float>?
    
    /// Use average of recent positions to avoid jitter
    private var recentPreviewNodePositions: [SIMD3<Float>] = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    convenience init(node: SCNNode) {
        self.init()
        opacity = 0.5
        addChildNode(node)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Appearence
    
    func update(for position: SIMD3<Float>, planeAnchor: ARPlaneAnchor?, camera: ARCamera?) {
        lastPosition = position
        if planeAnchor != nil {
            lastPositionOnPlane = position
        }
        updateTransform(for: position, camera: camera)
    }
    
    // MARK: - Internal
    
    private func updateTransform(for position: SIMD3<Float>, camera: ARCamera?) {
        // Add to the list of recent positions.
        recentPreviewNodePositions.append(position)
        
        // Remove anything older than the last 8 positions.
        recentPreviewNodePositions.keepLast(8)
        
        // Move to average of recent positions to avoid jitter.
        if let average = recentPreviewNodePositions.average {
            simdPosition = average
        }
    }
}
