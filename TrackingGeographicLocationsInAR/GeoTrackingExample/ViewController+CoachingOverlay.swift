/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller extension for the on-boarding experience.
*/

import UIKit
import ARKit

// The delegate for a view that presents visual instructions that guide the user during session
// initialization and recovery. For an example that explains more about coaching overlay, see:
// `Placing Objects and Handling 3D Interaction`
// <https://developer.apple.com/documentation/arkit/world_tracking/placing_objects_and_handling_3d_interaction>
//
extension ViewController: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        mapView.isUserInteractionEnabled = false
        undoButton.isEnabled = false
        hideUIForCoaching(true)
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        mapView.isUserInteractionEnabled = true
        undoButton.isEnabled = true
        hideUIForCoaching(false)
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        restartSession()
    }

    // Sets up the coaching view.
    func setupCoachingOverlay() {
        coachingOverlay.delegate = self
        arView.addSubview(coachingOverlay)
        coachingOverlay.goal = .geoTracking
        coachingOverlay.session = arView.session
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: arView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: arView.heightAnchor)
            ])
    }
    
    func hideUIForCoaching(_ active: Bool) {
        undoButton.isHidden = active
        trackingStateLabel.isHidden = active
    }
}
