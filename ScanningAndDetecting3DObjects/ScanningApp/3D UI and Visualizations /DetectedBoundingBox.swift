/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A simple visualiation of a 3D bounding box, used when testing detection of a scanned object.
*/

import Foundation
import ARKit

class DetectedBoundingBox: SCNNode {
    
    init(points: [SIMD3<Float>], scale: CGFloat, color: UIColor = .appYellow) {
        super.init()
        
        var localMin = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var localMax = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        
        for point in points {
            localMin = min(localMin, point)
            localMax = max(localMax, point)
        }
        
        self.simdPosition += (localMax + localMin) / 2
        let extent = localMax - localMin
        let wireframe = Wireframe(extent: extent, color: color, scale: scale)
        self.addChildNode(wireframe)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
