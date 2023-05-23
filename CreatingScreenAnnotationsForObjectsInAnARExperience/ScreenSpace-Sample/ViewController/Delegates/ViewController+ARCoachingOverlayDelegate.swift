/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ARCoachingOverlay additions to the app's main view controller.
*/

import ARKit

extension ViewController: ARCoachingOverlayViewDelegate {
        
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {

        messageLabel.ignoreMessages = true
        messageLabel.isHidden = true
        
        // Disables user interaction when the coaching overlay activates.
        view.isUserInteractionEnabled = false
        
        // Stops editing of sticky notes if any are being edited when the coaching overlay activates.
        for stickyNote in stickyNotes where stickyNote.isEditing {
            stickyNote.shouldAnimate = true
            stickyNote.isEditing = false
            guard let stickyView = stickyNote.view else { return }
            stickyView.textView.dismissKeyboard()
        }
    }
    
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        
        messageLabel.ignoreMessages = false
        
        // Re-enables user interaction once the coaching overlay deactivates.
        view.isUserInteractionEnabled = true
    }
    
}
