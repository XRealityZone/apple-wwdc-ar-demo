/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The main view controller.
*/

import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    
    // MARK: - Properties
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var messageLabel: MessageLabel!
    @IBOutlet weak var restartButton: UIButton!
    
    let coachingOverlay = ARCoachingOverlayView()
    let configuration = ARWorldTrackingConfiguration()
    
    /// - Tag: HeadPreview
    var headPreview: RobotHead?
    
    enum Instruction: String {
        case freezeFacialExpression = "Tap to freeze facial expression"
        case noFaceDetected = "Face not recognized"
        case moveFurtherAway = "Move further away from placed head"
    }
    
    // MARK: - View controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard ARWorldTrackingConfiguration.supportsUserFaceTracking else {
            fatalError("This sample code requires iOS 13 / iPad OS 13, and an iOS device with a front TrueDepth camera. Note: 2020 iPads do not support user face-tracking while world tracking.")
        }
        
        arView.session.delegate = self
        
        // We want to run a custom configuration.
        arView.automaticallyConfigureSession = false
        
        setupCoachingOverlay()

        // Make sure the robot head remains crisp at all times when attached to the camera.
        arView.renderOptions.insert(.disableMotionBlur)
        
        // Enable environment texturing.
        configuration.environmentTexturing = .automatic
        
        // Enable tracking the user's face during the world tracking session.
        configuration.userFaceTrackingEnabled = true
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))
    }

    /// - Tag: RunConfiguration
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arView.session.run(configuration)
    }
    
    // MARK: - User interaction and messages
    /// - Tag: HandleTap
    @objc
    func handleTap(recognizer: UITapGestureRecognizer) {
        guard let robotHeadPreview = headPreview, robotHeadPreview.isEnabled, robotHeadPreview.appearance == .tracked else {
            return
        }
        let headWorldTransform = robotHeadPreview.transformMatrix(relativeTo: nil)
        robotHeadPreview.anchor?.reanchor(.world(transform: headWorldTransform))
        robotHeadPreview.appearance = .anchored
        // ...

        // By setting the `headPreview` to nil, it prevents the app from updating
        // its facial expression in `session(didUpdate anchors:)`.
        self.headPreview = nil
    }
    
    @IBAction func restartButtonPressed(_ sender: Any) {
        resetTracking()
    }
    
    func resetTracking() {
        headPreview = nil
        arView.scene.anchors.removeAll()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        messageLabel.displayMessage("")
    }
    
    private func displayErrorMessage(for error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    private func showInstruction(_ instruction: Instruction) {
        messageLabel.displayMessage(instruction.rawValue, duration: 5)
    }
    
    private func updateHeadPreviewAppearance(for frame: ARFrame) {
        
        guard let robotHeadPreview = headPreview else { return }
        
        if robotHeadPreview.isTooCloseToAnchoredHeads(in: arView.scene) {
            robotHeadPreview.appearance = .intersecting
            showInstruction(.moveFurtherAway)
            return
        }

        let faceAnchors = frame.anchors.compactMap { $0 as? ARFaceAnchor }
        
        if faceAnchors.first(where: { $0.isTracked }) != nil {
            robotHeadPreview.appearance = .tracked
            showInstruction(.freezeFacialExpression)
        } else {
            robotHeadPreview.appearance = .notTracked
            showInstruction(.noFaceDetected)
        }
    }
    
    private func addHeadPreview() {
        // Create an anchor entity that follows the position of the camera.
        // Note: We need to recreate a new camera anchor here for every new head -
        // the reanchoring when tapping the screen changes the previous anchor.
        let camera = AnchorEntity(.camera)
        arView.scene.addAnchor(camera)

        // Attach a robot head to the camera anchor.
        let robotHead = RobotHead()
        camera.addChild(robotHead)
        
        // Move the head behind the camera to keep it hidden until the user's face is first tracked.
        robotHead.position.z = 1.0
        
        headPreview = robotHead
    }
    
    // MARK: - ARSessionDelegate
    
    /// Add a new robot head when no robot head is currently attached to the camera
    /// and the tracking state is 'normal'.
    /// - Tag: AddHeadPreview
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if headPreview == nil, case .normal = frame.camera.trackingState {
            addHeadPreview()
        }
        //...
        // Only show floating head if the coaching overlay isn't shown.
        headPreview?.isEnabled = !coachingOverlay.isActive
        
        // Update the head's appearance to reflect whether the user's face is tracked
        // or the floating head intersects with already anchored heads.
        updateHeadPreviewAppearance(for: frame)
    }
    
    /// If there is a floating robot head, update its model
    /// based on the face anchor's transform and current blend shapes.
    /// - Tag: UpdateFacialExpression
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARFaceAnchor }.forEach { headPreview?.update(with: $0) }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        displayErrorMessage(for: error)
    }
        
    // MARK: - Overrides
    
    override var prefersStatusBarHidden: Bool {
        // If possible, hide the status bar to improve immersiveness of the AR experience.
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        // If possible, hide the home indicator to improve immersiveness of the AR experience.
        return true
    }
}
