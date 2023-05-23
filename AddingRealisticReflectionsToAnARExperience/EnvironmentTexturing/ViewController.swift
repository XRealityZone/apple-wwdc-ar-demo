/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    struct ManualProbe {
        // An environment probe for shading the virtual object.
        var objectProbeAnchor: AREnvironmentProbeAnchor?
        // A fallback environment probe encompassing the whole scene.
        var sceneProbeAnchor: AREnvironmentProbeAnchor?
        // Indicates whether manually placed probes need updating.
        var requiresRefresh: Bool = true
        // Tracks timing of manual probe updates to prevent updating too frequently.
        var lastUpdateTime: TimeInterval = 0
    }
    
    // MARK: IBOutlets
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sessionInfoView: UIVisualEffectView!
    @IBOutlet weak var textureModeSelectionControl: UISegmentedControl!
    
    // MARK: - ARKit Configuration Properties
    
    // Model of shiny sphere that is added to the scene
    var virtualObjectModel: SCNNode = {
        guard let sceneURL = Bundle.main.url(forResource: "sphere", withExtension: "scn", subdirectory: "Models.scnassets/sphere"),
            let referenceNode = SCNReferenceNode(url: sceneURL) else {
                fatalError("can't load virtual object")
        }
        referenceNode.load()
        
        return referenceNode
    }()
    
    // MARK: - Environment Texturing Configuration
    
    /// The virtual object that the user interacts with in the scene.
    var virtualObject: SCNNode?
    /// Object to manage the manual environment probe anchor and its state
    var manualProbe: ManualProbe?
    
    /// Place environment probes manually or allow ARKit to place them automatically.
    var environmentTexturingMode: ARWorldTrackingConfiguration.EnvironmentTexturing = .automatic {
        didSet {
            switch environmentTexturingMode {
            case .manual:
                manualProbe = ManualProbe()
            default:
                manualProbe = nil
            }
        }
    }
    
    /// Indicates whether ARKit has provided an environment texture.
    var isEnvironmentTextureAvailable = false
    
    /// The latest screen touch position when a pan gesture is active
    var lastPanTouchPosition: CGPoint?

    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        switch environmentTexturingMode {
        case .manual:
            textureModeSelectionControl.selectedSegmentIndex = 1
        case .automatic:
            textureModeSelectionControl.selectedSegmentIndex = 0
        default:
            fatalError("This app supports only manual and automatic environment texturing.")
        }
    }

    /// - Tag: RunARSession
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from dimming to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR session with automatic environment texturing.
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    // MARK: - Session management
    
    @IBAction func changeMode(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            environmentTexturingMode = .automatic
        } else {
            environmentTexturingMode = .manual
        }
        // Remove anchors and change texturing mode
        resetTracking(changeMode: true)
    }
    
    @IBAction func restartExperience() {
        virtualObject?.removeFromParentNode()
        virtualObject = nil
        
        resetTracking()
    }
    
    /// Runs the session with a new AR configuration to change modes or reset the experience.
    func resetTracking(changeMode: Bool = false) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = environmentTexturingMode
        
        let session = sceneView.session
        if changeMode {
            // Remove existing environment probe anchors.
            session.currentFrame?.anchors
                .filter { $0 is AREnvironmentProbeAnchor }
                .forEach { session.remove(anchor: $0) }

            // Don't reset tracking when changing modes in the same session.
            session.run(configuration)
        } else {
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
        
        isEnvironmentTextureAvailable = false
    }
    
    /// Updates the UI to provide feedback on the state of the AR experience.
    func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        let message: String?
        
        switch trackingState {
        case .notAvailable:
            message = "Tracking Unavailable"
        case .limited(.excessiveMotion):
            message = "Tracking Limited\nExcessive motion - Try slowing down your movement, or reset the session."
        case .limited(.insufficientFeatures):
            message = "Tracking Limited\nLow detail - Try pointing at a flat surface, or reset the session."
        case .limited(.initializing):
            message = "Initializing"
        case .limited(.relocalizing):
            message = "Recovering from interruption"
        case .normal where virtualObject == nil:
            if isEnvironmentTextureAvailable {
                message = "Tap to place a sphere, then tap or drag to move it or pinch to scale it."
            } else {
                message = "Generating environment texture."
            }
        default:
            message = nil
        }
        
        // Show the message, or hide the label if there's no message.
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25) {
                self.sessionInfoLabel.text = message
                if message != nil {
                    self.sessionInfoView.alpha = 1
                } else {
                    self.sessionInfoView.alpha = 0
                }
            }
        }
    }
    
    // MARK: - Environment Texturing
    
    /// - Tag: ManualProbePlacement
    func updateEnvironmentProbe(atTime time: TimeInterval) {
        // Update the probe only if the object has been moved or scaled,
        // only when manually placed, not too often.
        guard let object = virtualObject,
            environmentTexturingMode == .manual,
            var manualProbe = manualProbe,
            time - manualProbe.lastUpdateTime >= 1.0,
            manualProbe.requiresRefresh
            else { return }
        
        // Remove existing probe anchor, if any.
        if let probeAnchor = manualProbe.objectProbeAnchor {
            sceneView.session.remove(anchor: probeAnchor)
            manualProbe.objectProbeAnchor = nil
        }
        
        // Make sure the probe encompasses the object and provides some surrounding area to appear in reflections.
        var extent = object.extents * object.simdScale
        extent.x *= 3 // Reflect an area 3x the width of the object.
        extent.z *= 3 // Reflect an area 3x the depth of the object.
        
        // Also include some vertical area around the object, but keep the bottom of the probe at the
        // bottom of the object so that it captures the real-world surface underneath.
        let verticalOffset = float3(0, extent.y, 0)
        let transform = float4x4(translation: object.simdPosition + verticalOffset)
        extent.y *= 2
        
        // Create the new environment probe anchor and add it to the session.
        let probeAnchor = AREnvironmentProbeAnchor(transform: transform, extent: extent)
        sceneView.session.add(anchor: probeAnchor)
        
        // Remember state to prevent updating the environment probe too often.
        manualProbe.objectProbeAnchor = probeAnchor
        manualProbe.lastUpdateTime = CACurrentMediaTime()
        manualProbe.requiresRefresh = false
        
        self.manualProbe = manualProbe
    }
    
    /// - Tag: FallbackEnvironmentProbe
    func updateSceneEnvironmentProbe(for frame: ARFrame) {
        guard environmentTexturingMode == .manual,
            let manualProbe = manualProbe,
            manualProbe.sceneProbeAnchor == nil
            else { return }
        
        // Create an environment probe anchor with room-sized extent to act as fallback when the probe anchor of
        // an object is removed and added during translation and scaling
        let probeAnchor = AREnvironmentProbeAnchor(name: "sceneProbe", transform: matrix_identity_float4x4, extent: float3(5))
        sceneView.session.add(anchor: probeAnchor)
        self.manualProbe?.sceneProbeAnchor = probeAnchor
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateEnvironmentProbe(atTime: time)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Check for whether any environment textures have been generated.
        guard let envProbeAnchor = anchor as? AREnvironmentProbeAnchor, !isEnvironmentTextureAvailable
            else { return }
        
        isEnvironmentTextureAvailable = envProbeAnchor.environmentTexture != nil
    }
    
    // MARK: - ARSessionObserver
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let frame = session.currentFrame else { fatalError("ARSession should have an ARFrame") }
        updateSessionInfoLabel(for: frame, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
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
    
    // MARK: ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateSceneEnvironmentProbe(for: frame)
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }

    // MARK: Virtual Object gesture interaction
    
    @IBAction func didPan(_ gesture: UIPanGestureRecognizer) {
        guard let object = virtualObject else { return }
        
        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: sceneView)
            
            let previousPosition = lastPanTouchPosition ?? CGPoint(sceneView.projectPoint(object.position))
            // Calculate the new touch position
            let currentPosition = CGPoint(x: previousPosition.x + translation.x, y: previousPosition.y + translation.y)
            if let hitTestResult = sceneView.smartHitTest(currentPosition) {
                object.simdPosition = hitTestResult.worldTransform.translation
                // Refresh the probe as the object keeps moving
                manualProbe?.requiresRefresh = true
            }
            lastPanTouchPosition = currentPosition
            // reset the gesture's translation
            gesture.setTranslation(.zero, in: sceneView)
        default:
            // Clear the current position tracking.
            lastPanTouchPosition = nil
        }
    }
    
    @IBAction func didTap(_ gesture: UITapGestureRecognizer) {
        // Allow placing objects only when ARKit tracking is in a good state for hit testing,
        // and environment texture is available (to prevent undesirable changes in reflected texture).
        guard let camera = sceneView.session.currentFrame?.camera, case .normal = camera.trackingState, isEnvironmentTextureAvailable else { return }
        let touchLocation = gesture.location(in: sceneView)
        
        if let object = virtualObject {
            if let hitTestResult = sceneView.smartHitTest(touchLocation) {
                // Teleport the object to wherever the user touched the screen.
                object.simdPosition = hitTestResult.worldTransform.translation
                // Update the environment probe anchor when object is teleported.
                manualProbe?.requiresRefresh = true
            }
        } else {
            // Add the object to the scene at the tap location.
            DispatchQueue.global().async {
                self.place(self.virtualObjectModel, basedOn: touchLocation)
                
                // Newly added object requires an environment probe anchor.
                self.manualProbe?.requiresRefresh = true
            }
        }
    }
    
    @IBAction func didScale(_ gesture: UIPinchGestureRecognizer) {
        guard let object = virtualObject, gesture.state == .changed
            else { return }
        let newScale = object.simdScale * Float(gesture.scale)
        object.simdScale = newScale
        gesture.scale = 1.0
        // Realistic reflections require an environment probe extent based on the size of the object,
        // so update the environment probe when the object is resized.
        manualProbe?.requiresRefresh = true
    }
    
    func place(_ object: SCNNode, basedOn location: CGPoint) {
        guard let hitTestResult = sceneView.smartHitTest(location)
            else { return }
        sceneView.scene.rootNode.addChildNode(object)
        virtualObject = object // Remember that the object has been placed.
        
        object.simdPosition = hitTestResult.worldTransform.translation
        
        // Update the status UI to indicate the newly placed object.
        guard let frame = sceneView.session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
}
