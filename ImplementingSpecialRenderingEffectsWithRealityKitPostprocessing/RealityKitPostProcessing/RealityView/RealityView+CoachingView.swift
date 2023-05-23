/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityView extension to hold methods related to the Coaching Overlay.
*/

import Foundation
import ARKit
import RealityKit

@available(iOS 15.0, *)
extension RealityView: ARCoachingOverlayViewDelegate {
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        ApplicationState.shared.isCoachingViewShowing = false
    }
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        ApplicationState.shared.isCoachingViewShowing = true
    }
}
