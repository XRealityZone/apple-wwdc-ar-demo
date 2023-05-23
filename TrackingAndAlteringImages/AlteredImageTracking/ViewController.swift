/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller that recognizes and tracks images found in the user's environment.
*/

import ARKit
import Foundation
import SceneKit
import UIKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messagePanel: UIView!
    @IBOutlet weak var messageLabel: UILabel!

    static var instance: ViewController?
    
    /// An object that detects rectangular shapes in the user's environment.
    let rectangleDetector = RectangleDetector()
    
    /// An object that represents an augmented image that exists in the user's environment.
    var alteredImage: AlteredImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        rectangleDetector.delegate = self
        sceneView.delegate = self
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
        ViewController.instance = self
		
		// Prevent the screen from being dimmed after a while.
		UIApplication.shared.isIdleTimerDisabled = true
        
        searchForNewImageToTrack()
	}
    
    func searchForNewImageToTrack() {
        alteredImage?.delegate = nil
        alteredImage = nil
        
        // Restart the session and remove any image anchors that may have been detected previously.
        runImageTrackingSession(with: [], runOptions: [.removeExistingAnchors, .resetTracking])
        
        showMessage("Look for a rectangular image.", autoHide: false)
    }
    
    /// - Tag: ImageTrackingSession
    private func runImageTrackingSession(with trackingImages: Set<ARReferenceImage>,
                                         runOptions: ARSession.RunOptions = [.removeExistingAnchors]) {
        let configuration = ARImageTrackingConfiguration()
        configuration.maximumNumberOfTrackedImages = 1
        configuration.trackingImages = trackingImages
        sceneView.session.run(configuration, options: runOptions)
    }
    
    // The timer for message presentation.
    private var messageHideTimer: Timer?
    
    func showMessage(_ message: String, autoHide: Bool = true) {
        DispatchQueue.main.async {
            self.messageLabel.text = message
            self.setMessageHidden(false)
            
            self.messageHideTimer?.invalidate()
            if autoHide {
                self.messageHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    self?.setMessageHidden(true)
                }
            }
        }
    }
    
    private func setMessageHidden(_ hide: Bool) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: {
                self.messagePanel.alpha = hide ? 0 : 1
            })
        }
    }
    
    /// Handles tap gesture input.
    @IBAction func didTap(_ sender: Any) {
        alteredImage?.pauseOrResumeFade()
    }
}

extension ViewController: ARSCNViewDelegate {
    
    /// - Tag: ImageWasRecognized
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        alteredImage?.add(anchor, node: node)
        setMessageHidden(true)
    }

    /// - Tag: DidUpdateAnchor
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        alteredImage?.update(anchor)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        if arError.code == .invalidReferenceImage {
            // Restart the experience, as otherwise the AR session remains stopped.
            // There's no benefit in surfacing this error to the user.
            print("Error: The detected rectangle cannot be tracked.")
            searchForNewImageToTrack()
            return
        }
        
        let errorWithInfo = arError as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Use `compactMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            
            // Present an alert informing about the error that just occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.searchForNewImageToTrack()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

extension ViewController: RectangleDetectorDelegate {
    /// Called when the app recognized a rectangular shape in the user's envirnment.
    /// - Tag: CreateReferenceImage
    func rectangleFound(rectangleContent: CIImage) {
        DispatchQueue.main.async {
            
            // Ignore detected rectangles if the app is currently tracking an image.
            guard self.alteredImage == nil else {
                return
            }
            
            guard let referenceImagePixelBuffer = rectangleContent.toPixelBuffer(pixelFormat: kCVPixelFormatType_32BGRA) else {
                print("Error: Could not convert rectangle content into an ARReferenceImage.")
                return
            }
            
            /*
             Set a default physical width of 50 centimeters for the new reference image.
             While this estimate is likely incorrect, that's fine for the purpose of the
             app. The content will still appear in the correct location and at the correct
             scale relative to the image that's being tracked.
             */
            let possibleReferenceImage = ARReferenceImage(referenceImagePixelBuffer, orientation: .up, physicalWidth: CGFloat(0.5))
            
            possibleReferenceImage.validate { [weak self] (error) in
                if let error = error {
                    print("Reference image validation failed: \(error.localizedDescription)")
                    return
                }

                // Try tracking the image that lies within the rectangle which the app just detected.
                guard let newAlteredImage = AlteredImage(rectangleContent, referenceImage: possibleReferenceImage) else { return }
                newAlteredImage.delegate = self
                self?.alteredImage = newAlteredImage
                
                // Start the session with the newly recognized image.
                self?.runImageTrackingSession(with: [newAlteredImage.referenceImage])
            }
        }
    }
}

/// Enables the app to create a new image from any rectangular shapes that may exist in the user's environment.
extension ViewController: AlteredImageDelegate {
    func alteredImageLostTracking(_ alteredImage: AlteredImage) {
        searchForNewImageToTrack()
    }
}
