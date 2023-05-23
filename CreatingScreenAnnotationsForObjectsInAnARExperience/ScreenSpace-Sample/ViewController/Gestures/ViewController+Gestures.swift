/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Gesture additions to the app's main view controller.
*/

import UIKit
import ARKit

extension ViewController {
    
    // MARK: - Gesture recognizer setup
    // - Tag: AddViewTapGesture
    func arViewGestureSetup() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedOnARView))
        arView.addGestureRecognizer(tapGesture)
        
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipedDownOnARView))
        swipeGesture.direction = .down
        arView.addGestureRecognizer(swipeGesture)
    }
    
    func stickyNoteGestureSetup(_ note: StickyNoteEntity) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panOnStickyView))
        note.view?.addGestureRecognizer(panGesture)
        
        let tapOnStickyView = UITapGestureRecognizer(target: self, action: #selector(tappedOnStickyView(_:)))
        note.view?.addGestureRecognizer(tapOnStickyView)
    }
    
    // MARK: - Gesture recognizer callbacks
    
    /// Tap gesture input handler.
    /// - Tag: TapHandler
    @objc
    func tappedOnARView(_ sender: UITapGestureRecognizer) {
        
        // Ignore the tap if the user is editing a sticky note.
        for note in stickyNotes where note.isEditing { return }
        
        // Create a new sticky note at the tap location.
        insertNewSticky(sender)
    }
    
    /**
    Hit test the feature point cloud and use any hit as the position of a new StickyNote. Otherwise, display a tip.
     - Tag: ScreenSpaceViewInsertionTag
     */
    fileprivate func insertNewSticky(_ sender: UITapGestureRecognizer) {

        // Get the user's tap screen location.
        let touchLocation = sender.location(in: arView)
        
        // Cast a ray to check for its intersection with any planes.
        guard let raycastResult = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .any).first else {
            messageLabel.displayMessage("No surface detected, try getting closer.", duration: 2.0)
            return
        }
        
        // Create a new sticky note positioned at the hit test result's world position.
        let frame = CGRect(origin: touchLocation, size: CGSize(width: 200, height: 200))

        let note = StickyNoteEntity(frame: frame, worldTransform: raycastResult.worldTransform)
        
        // Center the sticky note's view on the tap's screen location.
        note.setPositionCenter(touchLocation)

        // Add the sticky note to the scene's entity hierarchy.
        arView.scene.addAnchor(note)

        // Add the sticky note's view to the view hierarchy.
        guard let stickyView = note.view else { return }
        arView.insertSubview(stickyView, belowSubview: trashZone)
        
        // Enable gestures on the sticky note.
        stickyNoteGestureSetup(note)

        // Save a reference to the sticky note.
        stickyNotes.append(note)
        
        // Volunteer to handle text view callbacks.
        stickyView.textView.delegate = self
    }

    /// Dismisses the keyboard.
    @objc
    func swipedDownOnARView(_ sender: UISwipeGestureRecognizer) {
        dismissKeyboard()
    }
    
    fileprivate func dismissKeyboard() {
        for note in stickyNotes {
            guard let textView = note.view?.textView else { continue }
            if textView.isFirstResponder {
                textView.resignFirstResponder()
                return
            }
        }
    }
    
    @objc
    func tappedOnStickyView(_ sender: UITapGestureRecognizer) {
        guard let stickyView = sender.view as? StickyNoteView else { return }
        stickyView.textView.becomeFirstResponder()
    }
    //- Tag: PanOnStickyView
    fileprivate func panStickyNote(_ sender: UIPanGestureRecognizer, _ stickyView: StickyNoteView, _ panLocation: CGPoint) {
        messageLabel.isHidden = true
        
        let feedbackGenerator = UIImpactFeedbackGenerator()
        
        switch sender.state {
        case .began:
            // Prepare the taptic engine to reduce latency in delivering feedback.
            feedbackGenerator.prepare()
            
            // Drag if the gesture is beginning.
            stickyView.stickyNote.isDragging = true
            
            // Save offsets to implement smooth panning.
            guard let frame = sender.view?.frame else { return }
            stickyView.xOffset = panLocation.x - frame.origin.x
            stickyView.yOffset = panLocation.y - frame.origin.y
            
            // Fade in the widget that's used to delete sticky notes.
            trashZone.fadeIn(duration: 0.4)
        case .ended:
            // Stop dragging if the gesture is ending.
            stickyView.stickyNote.isDragging = false
            
            // Delete the sticky note if the gesture ended on the trash widget.
            if stickyView.isInTrashZone {
                deleteStickyNote(stickyView.stickyNote)
                // ...
            } else {
                attemptRepositioning(stickyView)
            }
            
            // Fades out the widget that's used to delete sticky notes when there are no sticky notes currently being dragged.
            if !stickyNotes.contains(where: { $0.isDragging }) {
                trashZone.fadeOut(duration: 0.2)
            }
        default:
            // Update the sticky note's screen position based on the pan location, and initial offset.
            stickyView.frame.origin.x = panLocation.x - stickyView.xOffset
            stickyView.frame.origin.y = panLocation.y - stickyView.yOffset
            
            // Give feedback whenever the pan location is near the widget used to delete sticky notes.
            trashZoneThresholdFeedback(sender, feedbackGenerator)
        }
    }
    
    /// Sticky note pan-gesture handler.
    /// - Tag: PanHandler
    @objc
    func panOnStickyView(_ sender: UIPanGestureRecognizer) {
        
        guard let stickyView = sender.view as? StickyNoteView else { return }
        
        let panLocation = sender.location(in: arView)
        
        // Ignore the pan if any StickyViews are being edited.
        for note in stickyNotes where note.isEditing { return }
        
        panStickyNote(sender, stickyView, panLocation)
    }
    
    func deleteStickyNote(_ note: StickyNoteEntity) {
        guard let index = stickyNotes.firstIndex(of: note) else { return }
        note.removeFromParent()
        stickyNotes.remove(at: index)
        note.view?.removeFromSuperview()
        note.view?.isInTrashZone = false
    }
    
    /// - Tag: AttemptRepositioning
    fileprivate func attemptRepositioning(_ stickyView: StickyNoteView) {
        // Conducts a ray-cast for feature points using the panned position of the StickyNoteView
        let point = CGPoint(x: stickyView.frame.midX, y: stickyView.frame.midY)
        if let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first {
            stickyView.stickyNote.transform.matrix = result.worldTransform
        } else {
            messageLabel.displayMessage("No surface detected, unable to reposition note.", duration: 2.0)
            stickyView.stickyNote.shouldAnimate = true
        }
    }
    
    fileprivate func trashZoneThresholdFeedback(_ sender: UIPanGestureRecognizer, _ feedbackGenerator: UIImpactFeedbackGenerator) {
        
        guard let stickyView = sender.view as? StickyNoteView else { return }
        
        let panLocation = sender.location(in: trashZone)
        
        if trashZone.frame.contains(panLocation), !stickyView.isInTrashZone {
            stickyView.isInTrashZone = true
            feedbackGenerator.impactOccurred()
            
        } else if !trashZone.frame.contains(panLocation), stickyView.isInTrashZone {
            stickyView.isInTrashZone = false
            feedbackGenerator.impactOccurred()
            
        }
    }
    
    @objc
    func tappedReset(_ sender: UIButton) {
        reset()
    }
    
}
