/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - IBOutlets
    
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var restartExperienceButton: UIButton!

    /// Source for audio playback
    var audioSource: SCNAudioSource!
    
    /// Holds a preview of the object while plane detection is in progress
    var previewNode: PreviewNode?
    
    /// Contains the virtual object that is placed in the real world
    var objectNode: SCNNode!
    
    /// Relocalization vars
    var isRelocalizing = false
    
    /// The center of the screen, used for determining the location of the preview and (placed) object nodes.
    var screenCenter: CGPoint!
    
    /// Marks if the AR experience is available for restart.
    var isRestartAvailable = true {
        didSet { restartExperienceButton.isEnabled = isRestartAvailable }
    }

    // MARK: - View Life Cycle
    
    /// - Tag: PreloadAudioSource
    override func viewDidLoad() {
        super.viewDidLoad()
        /*
         The `sceneView.automaticallyUpdatesLighting` option creates an
         ambient light source and modulates its intensity. This sample app
         instead modulates a global lighting environment map for use with
         physically based materials, so disable automatic lighting.
         */
        sceneView.automaticallyUpdatesLighting = false
        
        // Set up object node
        objectNode = SCNNode()
        // Set up audio playback
        setUpAudio()
        // Set up the capture camera
        setUpCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start the ARSession
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        // Calculate `screenCenter` based on the current device orientation.
        screenCenter = CGPoint( x: view.bounds.midX, y: view.bounds.midY )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
            // Stop the audio
        objectNode.removeAllAudioPlayers()
        // Pause the view's session
        sceneView.session.pause()
    }
    
    /// This method is overriden to recalculate the screen center on device orientation change.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Update `screenCenter` since the orientation of the device changed.
        screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    // MARK: - Internal methods
    
    private func setUpCamera() {
        guard let camera = sceneView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }
        // Enable HDR camera settings for the most realistic appearance
        // with environmental lighting and physically based materials.
        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }
    
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        // Reset any placed object or live preview
        objectNode.removeFromParentNode()
        objectNode = SCNNode()
        previewNode?.removeFromParentNode()
        previewNode = nil
    }
    
    /// Called after the session state has changed to "relocalizing"
    private func beginRelocalization() {
        // Reset the session if the object is not currently placed.
        if objectNode.parent == nil { resetTracking(); return }
        isRelocalizing = true
        // Hide our the object because it's position is very likely incorrect.
        objectNode.isHidden = true
        // Mute audio since it can no longer be associated with our hidden content.
        guard let player = objectNode.audioPlayers.first,
            let avNode = player.audioNode as? AVAudioMixing else {
                return
        }
        avNode.volume = 0.0
    }
    
    /// Called after the session state has changed from `relocalizing` to `normal`
    private func endRelocalization() {
        if !isRelocalizing { return }
        isRelocalizing = false
        // Show the object and reenable audio
        objectNode.isHidden = false
        // Resume audio
        guard let player = objectNode.audioPlayers.first else {
            playSound()
            return
        }
        // Restore volume on the existing audio player
        if let avNode = player.audioNode as? AVAudioMixing {
            avNode.volume = 1.0
        }
    }
    
    /// - Tag: TransformConstraint
    /// Loads the model in `objectNode` and places it within the `previewNode`
    private func setUpPreviewNode() {
        // Only proceed if the object and preview need setting up, and resetExperience cooldown has completed.
        guard objectNode.parent == nil, isRestartAvailable else { return }
        objectNode = SCNNode()
        // Load the scene from the bundle only once.
        let modelScene = SCNScene(named: "Assets.scnassets/firehead/firehead.scn")!
        let modelNode = modelScene.rootNode.childNode(withName: "firehead", recursively: true)!
        // Set the model onto `objectNode`.
        objectNode.addChildNode(modelNode)
        // Initialize `previewNode` to display the model.
        previewNode = PreviewNode(node: objectNode)
        // Add `previewNode` to the node hierarchy.
        sceneView.scene.rootNode.addChildNode(previewNode!)
        // Create orientation constraint to fix the model's world orientation to match the scene's rootNode.
        let constraint = SCNTransformConstraint.orientationConstraint(inWorldSpace: true) { (_, _) -> SCNQuaternion in
            // This prevents the placed object from rotating about the y-axis if/when ARKit refines the ARPlaneAnchor's node.
            return self.sceneView.scene.rootNode.orientation
        }
        objectNode.constraints = [constraint]
    }
    
    /// The `previewNode` exists when ARKit is finding a plane. Get a world position for the areas closest to
    ///  the scene's point of view that ARKit believes might be a plane, and use it to update the `previewNode` position
    private func updatePreviewNode() {
        guard let preview = previewNode, let point = screenCenter else { return }
        // Perform hit testing only when ARKit tracking is in a good state.
        if let camera = sceneView.session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = sceneView.smartHitTest( point, infinitePlane: true, objectPosition: preview.simdWorldPosition, allowedAlignments: [.horizontal] ) {
            preview.update(for: result.worldTransform.translation, planeAnchor: result.anchor as? ARPlaneAnchor, camera: sceneView.session.currentFrame?.camera )
        }
    }
    
    // MARK: - IBActions
    
    @IBAction private func restartExperience(_ sender: UIButton) {
        guard isRestartAvailable else { return }
        isRestartAvailable = false
        resetTracking()
        // Disable restart for a while in order to give the session time to restart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            self.isRestartAvailable = true
        }
    }
    
    // MARK: - SCNSceneRendererDelegate
    
    /// Implementation of SCNSceneRendererDelegate's main rendering callback
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Set up a preview if the object has not yet been placed
        if objectNode.parent == nil {
            setUpPreviewNode()
        }
        // If the preview node is present, update its position
        updatePreviewNode()
    }
    
    // MARK: - ARSCNViewDelegate
    
    /// - Tag: ChildOfPlaneAnchorNode
    /// Implementation of ARSCNViewDelegate to handle the case when a plane is detected
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Continue if the anchor is a plane, and the object has not been placed
        guard anchor is ARPlaneAnchor, previewNode != nil else { return }
        
        // Separate the object node from the preview node
        objectNode.removeFromParentNode()
        // Remove `previewNode` from the node hierarchy
        previewNode?.removeFromParentNode()
        previewNode = nil
        
        // Create a player from the source and add it to `objectNode`
        objectNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
        // Place object node on top of the plane's node
        node.addChildNode(objectNode)
        
        // Disable plane detection after the model has been added
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [])
        
        // Play a positional environment sound layer from the newly placed object
        playSound()
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let message: String
        // Inform the user of the camera tracking state
        switch camera.trackingState {
        case .notAvailable:
            message = "Tracking unavailable"
        case .normal:
            message = "Tracking normal"
            endRelocalization()
        case .limited(.excessiveMotion):
            message = "Try slowing down your movement, or reset the session."
        case .limited(.insufficientFeatures):
            message = "Try pointing at a flat surface, or reset the session."
        case .limited(.initializing):
            message = "Initializing AR Session"
        case .limited(.relocalizing):
            beginRelocalization()
            message = "Recovering from interruption. Return to the location where you left off or try resetting the session."
        default:
            message = "Tracking unavailable"
        }
        sessionInfoLabel.text = message
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription). Resetting the AR session."
        resetTracking()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        sessionInfoLabel.text = "Session interruption ended"
        // If object has not been placed yet, reset tracking
        if previewNode != nil {
            resetTracking()
        }
    }
    
    /**
     Allow the session to attempt to resume after an interruption
     This process may not succeed, so the app must be prepared
     to reset the session if the relocalizing status continues
     for a long time
     */
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        // Only relocalize if the object had been placed
        if previewNode != nil { return false }
        return true
    }
    
    // MARK: - Sound
    /// Sets up the audio for playback.
    /// - Tag: SetUpAudio
    private func setUpAudio() {
        // Instantiate the audio source
        audioSource = SCNAudioSource(fileNamed: "fireplace.mp3")!
        // As an environmental sound layer, audio should play indefinitely
        audioSource.loops = true
        // Decode the audio from disk ahead of time to prevent a delay in playback
        audioSource.load()
    }
    /// Plays a sound on the `objectNode` using SceneKit's positional audio
    /// - Tag: AddAudioPlayer
    private func playSound() {
        // Ensure there is only one audio player
        objectNode.removeAllAudioPlayers()
        // Create a player from the source and add it to `objectNode`
        objectNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
    }
}
