/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that starts an AR session and coordinates the App Clip Code scanning experience.
*/

import UIKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController, ARSessionDelegate, ARCoachingOverlayViewDelegate {

    let arView = ARView()
    var appClipCodeCoachingOverlay: AppClipCodeCoachingOverlayView!
    var informationLabel: OverlayLabel!
    var unsupportedDeviceLabel: UILabel!
    let coachingOverlayWorldTracking = ARCoachingOverlayView()

    var useTestURL = true
    ///- Tag: TestAppClipCodeURL
    var testAppClipCodeURL = URL(string: "https://developer.apple.com/sunfl")!
    var decodedURLs: [URL] = []
    var detectionImageSet = Set<ARReferenceImage>()

    /* The model URL for App Clip Code URL-path-component dictionary.
     To enable the app to preview more grown plants, add entries to `modelForURL` for
     each additional grown plant. */
    ///- Tag: ModelURLFor
    let modelURLFor: [String: URL] = [
        "sunfl": URL(string: "https://developer.apple.com/sample-code/ar/sunflower.usdz")!
    ]
    var modelFor: [String: Entity] = [:]
    
    /* The image URL for App Clip Code URL-path-component dictionary.
     To enable the app to preview more grown plants, add entries to `imageForURL` for
     each additional seed packet. */
    ///- Tag: ImageURLFor
    ///
    let imageURLFor: [String: URL] = [
        "sunfl": URL(string: "https://developer.apple.com/sample-code/ar/sunflower.jpg")!
    ]
var imageAnchorFor: [String: AnchorEntity] = [:]
    
    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        guard ARWorldTrackingConfiguration.supportsAppClipCodeTracking else {
            displayUnsupportedDevicePrompt()
            return
        }
        
        initializeARView()
        initializeCoachingOverlays()
        initializeInformationLabel()
        
        if
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let sceneDelegate = windowScene.delegate as? SceneDelegate,
            let appClipCodeLaunchURL = sceneDelegate.appClipCodeURL
        {
            // To provide a faster user experience, use the launch URL to begin loading content.
            process(productKey: getProductKey(from: appClipCodeLaunchURL), initializePreview: false)
        }
    }
    
    /// Hides the instruction prompt once the user has detected an app clip code.
    ///- Tag: SessionDidAddAnchors
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARAppClipCodeAnchor {
                // Hide the coaching overlay since ARKit recognized an App Clip Code.
                appClipCodeCoachingOverlay.setCoachingViewHidden(true)
            }
            if let imageAnchor = anchor as? ARImageAnchor, let productKey = imageAnchor.referenceImage.name {
                // Hide the coaching overlay since ARKit recognized a seed packet.
                appClipCodeCoachingOverlay.setCoachingViewHidden(true)
                imageAnchorFor[productKey] = AnchorEntity(anchor: imageAnchor)
                arView.scene.addAnchor(imageAnchorFor[productKey]!)
                if let productModel = modelFor[productKey] {
                    // If the associated model is already loaded, present the model.
                    productModel.present(on: imageAnchorFor[productKey]!)
                }
            }
        }
    }
    ///- Tag: SessionDidUpdateAnchors
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let appClipCodeAnchor = anchor as? ARAppClipCodeAnchor, appClipCodeAnchor.urlDecodingState != .decoding {
                let decodedURL: URL
                switch appClipCodeAnchor.urlDecodingState {
                case .decoded:
                        decodedURL = appClipCodeAnchor.url!
                        if !decodedURLs.contains(decodedURL) {
                            decodedURLs.append(decodedURL)
                            process(productKey: getProductKey(from: decodedURL))
                            NSLog("Successfully decoded ARAppClipCodeAnchor url: " + decodedURL.absoluteString)
                        }
                case .failed:
                        if useTestURL {
                            decodedURL = testAppClipCodeURL
                            if !decodedURLs.contains(decodedURL) {
                                NSLog("ARAppClipCodeAnchor url decoding failure. Using the test URL instead: " + testAppClipCodeURL.absoluteString)
                                decodedURLs.append(decodedURL)
                                process(productKey: getProductKey(from: decodedURL))
                            }
                        } else {
                            showInformationLabel("Decoding failure. Trying scanning a code again.")
                        }
                case .decoding:
                    continue
                default:
                    continue
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.runARSession()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func displayUnsupportedDevicePrompt() {
        let promptText =
            """
            Device not supported
            
            App Clip Code tracking
            requires a device
            with an Apple Neural Engine.
            """
        unsupportedDeviceLabel = UILabel()
        unsupportedDeviceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(unsupportedDeviceLabel, at: 0)
        unsupportedDeviceLabel.fillParentView()
        unsupportedDeviceLabel.backgroundColor  = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        unsupportedDeviceLabel.adjustsFontSizeToFitWidth = false
        unsupportedDeviceLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        unsupportedDeviceLabel.text = promptText
        unsupportedDeviceLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        unsupportedDeviceLabel.textAlignment = .center
        unsupportedDeviceLabel.numberOfLines = 0
        unsupportedDeviceLabel.lineBreakMode = .byWordWrapping
    }
    
    func initializeARView() {
        UIApplication.shared.isIdleTimerDisabled = true
        
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)
        arView.fillParentView()
        
        arView.session.delegate = self
        runARSession()
    }
    
    func runARSession(withAdditionalReferenceImages additionalReferenceImages: Set<ARReferenceImage> = Set<ARReferenceImage>()) {
        if let currentConfiguration = (arView.session.configuration as? ARWorldTrackingConfiguration) {
            // Add the additional reference images to the current AR session.
            currentConfiguration.detectionImages = currentConfiguration.detectionImages.union(additionalReferenceImages)
            currentConfiguration.maximumNumberOfTrackedImages = currentConfiguration.detectionImages.count
            arView.session.run(currentConfiguration)
        } else {
            // Initialize a new AR session with App Clip Code tracking and image tracking.
            arView.automaticallyConfigureSession = false
            let newConfiguration = ARWorldTrackingConfiguration()
            newConfiguration.detectionImages = additionalReferenceImages
            newConfiguration.maximumNumberOfTrackedImages = newConfiguration.detectionImages.count
            newConfiguration.automaticImageScaleEstimationEnabled = true
            newConfiguration.appClipCodeTrackingEnabled = true
            arView.session.run(newConfiguration)
        }
    }
    
    func initializeCoachingOverlays() {
        appClipCodeCoachingOverlay = AppClipCodeCoachingOverlayView(parentView: arView)
        
        arView.addSubview(coachingOverlayWorldTracking)
        coachingOverlayWorldTracking.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlayWorldTracking.fillParentView()
        coachingOverlayWorldTracking.delegate = self
        coachingOverlayWorldTracking.session = arView.session
    }
    
    func initializeInformationLabel() {
        informationLabel = OverlayLabel()
        arView.addSubview(informationLabel)
        informationLabel.lowerCenterInParentView()
    }
    
    func showInformationLabel(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            debugPrint(message)
            if let isCoachingActive = self?.coachingOverlayWorldTracking.isActive, !isCoachingActive {
                self?.setInformationLabelHidden(false)
                self?.informationLabel.text = message
            }
        }
    }
    
    func setInformationLabelHidden(_ hide: Bool) {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: { [weak self] in
                self?.informationLabel.alpha = hide ? 0 : 1
            })
        }
    }
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        appClipCodeCoachingOverlay.setCoachingViewHidden(true)
        setInformationLabelHidden(true)
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        if decodedURLs.isEmpty {
            appClipCodeCoachingOverlay.setCoachingViewHidden(false)
        }
    }
    
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        initializeARView()
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}
