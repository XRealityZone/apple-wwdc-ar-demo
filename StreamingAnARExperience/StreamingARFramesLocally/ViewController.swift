/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The main ViewController of the sample app.
*/

import RealityKit
import MultipeerConnectivity
import MetalKit
import ReplayKit
import ARKit

/// - Tag: ViewController
class ViewController: UIViewController, ARSessionDelegate {
        
    // MARK: - Properties
    @IBOutlet var arView: ARView!
    
    // A weak reference to the root view controller of the overlay window.
    weak var overlayViewController: OverlayViewController?

    // Manages the multipeer connectivity session.
    lazy var multipeerSession = MultipeerSession(receivedDataHandler: receivedData,
                                                 peerDiscoveredHandler: peerDiscovered)
    
    // Video compressor/decompressor.
    let videoProcessor = VideoProcessor()
    
    // An entity that represents the location that the connected peer taps in the scene.
    let marker: AnchorEntity = {
        let entity = AnchorEntity()
        entity.addChild(ModelEntity(mesh: .generateSphere(radius: 0.05)))
        entity.isEnabled = false
        return entity
    }()
    
    // A tracked ray cast for placing the marker.
    private var trackedRaycast: ARTrackedRaycast?

    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Configure the arView.
        arView.session.delegate = self
        
        // Configure the scene.
        arView.scene.addAnchor(marker)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("Make sure that the app delegate is of type AppDelegate")
        }
        overlayViewController = appDelegate.overlayWindow?.rootViewController as? OverlayViewController
        
        overlayViewController?.multipeerSession = multipeerSession
        
        // Start ReplayKit capture and handle receiving video sample buffers.
        RPScreenRecorder.shared().startCapture {
            [self] (sampleBuffer, type, error) in
            if type == .video {
                guard let currentFrame = arView.session.currentFrame else { return }
                videoProcessor.compressAndSend(sampleBuffer, arFrame: currentFrame) {
                    (data) in
                    multipeerSession.sendToAllPeers(data, reliably: true)
                }
            }
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that occurs.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { [self] _ in
                alertController.dismiss(animated: true, completion: nil)
                guard let configuration = arView.session.configuration else {
                    fatalError("ARSession does not have a configuration.")
                }
                arView.session.run(configuration)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - MultipeerSession handlers
    ///- Tag: ReceivedData
    func receivedData(_ data: Data, from peer: MCPeerID) {
        // Try to decode the received data and handle it appropriately.
        if let videoFrameData = try? JSONDecoder().decode(VideoFrameData.self,
            from: data) {
            // Reconstruct a sample buffer of the compressed video frame data.
            let sampleBuffer = videoFrameData.makeSampleBuffer()
            // Decompress the sample buffer and enqueue it for rendering.
            videoProcessor.decompress(sampleBuffer) { [self] imageBuffer, presentationTimeStamp in
                // Update the PipView aspect ratio to match the camera-image dimensions.
                let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
                let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
                overlayViewController?.setPipViewConstraints(width: width, height: height)
                
                overlayViewController?.renderer.enqueueFrame(
                    pixelBuffer: imageBuffer,
                    presentationTimeStamp: presentationTimeStamp,
                    inverseProjectionMatrix: videoFrameData.inverseProjectionMatrix,
                    inverseViewMatrix: videoFrameData.inverseViewMatrix)
            }
        } else if let rayQuery = try? JSONDecoder().decode(Ray.self, from: data) {
            DispatchQueue.main.async { [self] in
                
                // Stop tracking the previous trackedRaycast.
                trackedRaycast?.stopTracking()
                
                // Replace the previous trackedRaycast.
                trackedRaycast = arView.session.trackedRaycast(
                    ARRaycastQuery(
                        origin: rayQuery.origin,
                        direction: rayQuery.direction,
                        allowing: .estimatedPlane,
                        alignment: .any)
                    ) {
                    raycastResults in
                    if let result = raycastResults.first {
                        marker.transform.matrix = result.worldTransform
                        marker.isEnabled = true
                    }
                }
            }
        }
    }
        
    func peerDiscovered(_ peer: MCPeerID) -> Bool {
        // Don't accept more than one user in the experience.
        multipeerSession.connectedPeers.count < 1
    }
    
    override var prefersStatusBarHidden: Bool {
        // If possible, hide the status bar to improve immersiveness of the AR experience.
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        // If possible, hide the Home indicator to improve immersiveness of the AR experience.
        return true
    }
}
