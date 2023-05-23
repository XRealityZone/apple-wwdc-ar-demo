/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Extensions to BoundingBox and ObjectOrigin for snapping to significant locations.
*/

import ARKit

extension BoundingBox {
    
    func snapToHorizontalPlane() {
        // Snap to align with horizontal plane if y-position is close enough
        let snapThreshold: Float = 0.01
        var isWithinSnapThreshold = false
        let bottomY = simdWorldPosition.y - extent.y / 2
        
        guard let currentFrame = ViewController.instance!.sceneView.session.currentFrame else { return }
        
        for anchor in currentFrame.anchors where anchor is ARPlaneAnchor {
            let distanceFromHorizontalPlane = abs(bottomY - anchor.transform.position.y)
            
            if distanceFromHorizontalPlane < snapThreshold {
                isWithinSnapThreshold = true
                self.simdWorldPosition.y = anchor.transform.position.y + extent.y / 2
                
                // Provide haptic feedback when reaching the snapThreshold for the first time
                if !isSnappedToHorizontalPlane {
                    isSnappedToHorizontalPlane = true
                    playHapticFeedback()
                }
            }
        }
        
        if !isWithinSnapThreshold {
            isSnappedToHorizontalPlane = false
        }
    }
}

extension ObjectOrigin {
    
    func snapToBoundingBoxSide() {
        guard let boundingBox = self.parent as? BoundingBox else { return }
        let extent = boundingBox.extent
        
        let snapThreshold: Float = 0.01
        var isWithinSnapThreshold = false
        
        if abs(extent.x / 2 - simdPosition.x) < snapThreshold {
            simdPosition.x = extent.x / 2
            isWithinSnapThreshold = true
        } else if abs(-extent.x / 2 - simdPosition.x) < snapThreshold {
            simdPosition.x = -extent.x / 2
            isWithinSnapThreshold = true
        }
        if abs(extent.y / 2 - simdPosition.y) < snapThreshold {
            simdPosition.y = extent.y / 2
            isWithinSnapThreshold = true
        } else if abs(-extent.y / 2 - simdPosition.y) < snapThreshold {
            simdPosition.y = -extent.y / 2
            isWithinSnapThreshold = true
        }
        if abs(extent.z / 2 - simdPosition.z) < snapThreshold {
            simdPosition.z = extent.z / 2
            isWithinSnapThreshold = true
        } else if abs(-extent.z / 2 - simdPosition.z) < snapThreshold {
            simdPosition.z = -extent.z / 2
            isWithinSnapThreshold = true
        }
        
        // Provide haptic feedback when reaching the snapThreshold for the first time
        if isWithinSnapThreshold && !isSnappedToSide {
            isSnappedToSide = true
            playHapticFeedback()
        } else if !isWithinSnapThreshold {
            isSnappedToSide = false
        }
    }
    
    func snapToBoundingBoxCenter() {
        guard let boundingBox = self.parent as? BoundingBox else { return }
        
        let snapThreshold: Float = 0.01
        let boundingBoxPos = boundingBox.simdPosition
        
        var isWithinSnapThreshold = false
        
        if abs(boundingBoxPos.x - simdPosition.x) < snapThreshold &&
            abs(boundingBoxPos.z - simdPosition.z) < snapThreshold {
            simdPosition = SIMD3<Float>(boundingBoxPos.x, simdPosition.y, boundingBoxPos.z)
            isWithinSnapThreshold = true
        }
        
        // Provide haptic feedback when reaching the snapThreshold for the first time
        if isWithinSnapThreshold && !isSnappedToBottomCenter {
            isSnappedToBottomCenter = true
            playHapticFeedback()
        } else if !isWithinSnapThreshold {
            isSnappedToBottomCenter = false
        }
    }
    
    func rotateWithSnappingOnYAxis(by angle: Float) {
        let snapInterval: Float = .pi / 2
        let snapThreshold: Float = 0.1 // 6°
        
        // Compute the snap angle, being the closest multiple of the snap interval.
        let snapAngle = round(eulerAngles.y / snapInterval) * snapInterval
        
        if !isSnappedTo90DegreeRotation {
            // Compute the delta between current angle and computed snap angle.
            let deltaToSnapAngle = abs(snapAngle - eulerAngles.y)
            
            // Snap if the delta is below the snap threshold, otherwise rotate by the angle received from the gesture.
            if deltaToSnapAngle < snapThreshold {
                simdLocalRotate(by: simd_quatf(angle: sign(angle) * deltaToSnapAngle, axis: .y))
                isSnappedTo90DegreeRotation = true
                totalRotationSinceLastSnap = 0
                playHapticFeedback()
            } else {
                simdLocalRotate(by: simd_quatf(angle: angle, axis: .y))
            }
        } else {
            totalRotationSinceLastSnap += angle
            
            // Unsnap if the total rotation since the snap exceeds the snap threshold.
            if abs(totalRotationSinceLastSnap) > snapThreshold {
                simdLocalRotate(by: simd_quatf(angle: totalRotationSinceLastSnap, axis: .y))
                isSnappedTo90DegreeRotation = false
            }
        }
    }
}

func playHapticFeedback() {
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    feedbackGenerator.impactOccurred()
}
