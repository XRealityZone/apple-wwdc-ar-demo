/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A visualization the 3D point cloud data in a detected object.
*/

import Foundation
import ARKit

class DetectedPointCloud: SCNNode, PointCloud {
    
    private let referenceObjectPointCloud: ARPointCloud
    private let center: SIMD3<Float>
    private let extent: SIMD3<Float>
    
    init(referenceObjectPointCloud: ARPointCloud, center: SIMD3<Float>, extent: SIMD3<Float>) {
        self.referenceObjectPointCloud = referenceObjectPointCloud
        self.center = center
        self.extent = extent
        super.init()
        
        // Semitransparently visualize the reference object's points.
        let referenceObjectPoints = SCNNode()
        referenceObjectPoints.geometry = createVisualization(for: referenceObjectPointCloud.points,
                                                             color: .appYellow, size: 12)
        addChildNode(referenceObjectPoints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateVisualization(for currentPointCloud: ARPointCloud) {
        guard !self.isHidden else { return }
        
        let min: SIMD3<Float> = simdPosition + center - extent / 2
        let max: SIMD3<Float> = simdPosition + center + extent / 2
        var inlierPoints: [SIMD3<Float>] = []
        
        for point in currentPointCloud.points {
            let localPoint = self.simdConvertPosition(point, from: nil)
            if (min.x..<max.x).contains(localPoint.x) &&
                (min.y..<max.y).contains(localPoint.y) &&
                (min.z..<max.z).contains(localPoint.z) {
                inlierPoints.append(localPoint)
            }
        }
        
        let currentPointCloudInliers = inlierPoints
        self.geometry = createVisualization(for: currentPointCloudInliers, color: .appGreen, size: 12)
    }
}
