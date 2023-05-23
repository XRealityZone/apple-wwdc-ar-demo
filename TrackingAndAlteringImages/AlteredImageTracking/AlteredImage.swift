/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that augments a rectangular shape that exists in the physical environment.
*/

import Foundation
import ARKit
import CoreML

/// - Tag: AlteredImage
class AlteredImage {

    let referenceImage: ARReferenceImage
    
    /// A handle to the anchor ARKit assigned the tracked image.
    private(set) var anchor: ARImageAnchor?
    
    /// A SceneKit node that animates images of varying style.
    private let visualizationNode: VisualizationNode
    
    /// Stores a reference to the Core ML output image.
    private var modelOutputImage: CVPixelBuffer?
    
    private var fadeBetweenStyles = true
    
    /// A timer that effects a grace period before checking
    ///  for a new rectangular shape in the user's environment.
    private var failedTrackingTimeout: Timer?
    
    /// The timeout in seconds after which the `imageTrackingLost` delegate is called.
    private var timeout: TimeInterval = 1.0
    
    /**
     The ML model to be used for the image alteration. For this class to compile, the model
     has to accept an input image called `image` and a style index called `index`.
     Note that this is static in order to avoid spikes in memory usage when replacing
     instances of the `AlteredImage` class.
     */
    private static var _styleTransferModel: StyleTransferModel!
    private static var styleTransferModel: StyleTransferModel! {
        get {
            if let model = _styleTransferModel { return model }
            _styleTransferModel = {
                do {
                    let configuration = MLModelConfiguration()
                    return try StyleTransferModel(configuration: configuration)
                } catch {
                    fatalError("Couldn't create StyleTransferModel due to: \(error)")
                }
            }()
            return _styleTransferModel
        }
    }
    
    /// The input parameters to the Core ML model.
    private var modelInputImage: CVPixelBuffer
    
    private var styleIndexArray: MLMultiArray
    
    private var numberOfStyles = 1
    
    /// The index of the current image's style.
    private var styleIndex = 0
    
    /// Increments the style index that's input into the Core ML model.
    /// - Tag: SelectNextStyle
    func selectNextStyle() {
        styleIndex = (styleIndex + 1) % numberOfStyles
    }
    
    /// A delegate to tell when image tracking fails.
    weak var delegate: AlteredImageDelegate?
    
    init?(_ image: CIImage, referenceImage: ARReferenceImage) {

        // Read the required input parameters of the Core ML model.
        var modelInputImageSize: CGSize? = nil
        var modelInputImageFormat: OSType = 0
        var styleIndexArrayShape: [NSNumber] = []
        var styleIndexDataType: MLMultiArrayDataType = .double
        
        // Parse the input parameters of the given Core ML model.
        for inputDescription in AlteredImage.styleTransferModel.model.modelDescription.inputDescriptionsByName {
            let featureDescription = inputDescription.value
            
            if featureDescription.type == .image {
                guard let featureConstraint = featureDescription.imageConstraint else {
                    fatalError("Assumption: `imageConstraint` should never be nil for feature descriptions of type `image`.")
                }
                let imageConstraint = featureConstraint
                modelInputImageSize = CGSize(width: imageConstraint.pixelsWide,
                                             height: imageConstraint.pixelsHigh)
                modelInputImageFormat = imageConstraint.pixelFormatType
            } else if featureDescription.type == .multiArray {
                guard let featureMultiArrayConstraint = featureDescription.multiArrayConstraint else {
                    fatalError("Assumption: `multiArrayConstraint` should never be nil for feature descriptions of type `multiArray`.")
                }
                let multiArrayConstraint = featureMultiArrayConstraint
                styleIndexArrayShape = multiArrayConstraint.shape
                styleIndexDataType = multiArrayConstraint.dataType
                if multiArrayConstraint.shape.count == 1 {
                    numberOfStyles = multiArrayConstraint.shape[0].intValue
                }
            }
        }
        
        do {
            styleIndexArray = try MLMultiArray(shape: styleIndexArrayShape, dataType: styleIndexDataType)
        } catch {
            print("Error: Could not create altered image input array.")
            return nil
        }
 
        // Scale the image to the size required by the ML model.
        guard let modelImageSize = modelInputImageSize,
            let resizedImage = image.resize(to: modelImageSize),
            let resizedPixelBuffer = resizedImage.toPixelBuffer(pixelFormat: modelInputImageFormat) else {
            print("Error: Could not convert input image to the model's expected format.")
            return nil
        }
        modelInputImage = resizedPixelBuffer
        
        self.referenceImage = referenceImage
        visualizationNode = VisualizationNode(referenceImage.physicalSize)
        
        visualizationNode.delegate = self
        
        // Start the failed tracking timer right away. This ensures that the app starts
        //  looking for a different image to track if this one isn't trackable.
        resetImageTrackingTimeout()
        
        // Start altering an image with the next style.
        createAlteredImage()
    }
    
    deinit {
        visualizationNode.removeAllAnimations()
        visualizationNode.removeFromParentNode()
    }
    
    /// Displays the altered image using the anchor and node provided by ARKit.
    /// - Tag: AddVisualizationNode
    func add(_ anchor: ARAnchor, node: SCNNode) {
        if let imageAnchor = anchor as? ARImageAnchor, imageAnchor.referenceImage == referenceImage {
            self.anchor = imageAnchor
            
            // Start the image tracking timeout.
            resetImageTrackingTimeout()
            
            // Add the node that displays the altered image to the node graph.
            node.addChildNode(visualizationNode)

            // If altering the first image completed before the
            //  anchor was added, display that image now.
            if let createdImage = modelOutputImage {
                visualizationNode.display(createdImage)
            }
        }
    }
    
    /**
     If an image the app was tracking is no longer tracked for a given amount of time, invalidate
     the current image tracking session. This, in turn, enables Vision to start looking for a new
     rectangular shape in the camera feed.
     - Tag: AnchorWasUpdated
     */
    func update(_ anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor, self.anchor == anchor {
            self.anchor = imageAnchor
            // Reset the timeout if the app is still tracking an image.
            if imageAnchor.isTracked {
                resetImageTrackingTimeout()
            }
        }
    }
    
    /// Toggles whether the app animates successive styles of the altered image.
    func pauseOrResumeFade() {
        guard visualizationNode.parent != nil else { return }
        
        fadeBetweenStyles.toggle()
        if fadeBetweenStyles {
            ViewController.instance?.showMessage("Resume fading between styles.")
        } else {
            ViewController.instance?.showMessage("Pause fading between styles.")
        }
        visualizationNodeDidFinishFade(visualizationNode)
    }
    
    /// Prevents the image tracking timeout from expiring.
    private func resetImageTrackingTimeout() {
        failedTrackingTimeout?.invalidate()
        failedTrackingTimeout = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            if let strongSelf = self {
                self?.delegate?.alteredImageLostTracking(strongSelf)
            }
        }
    }
    
    /// Alters the image's appearance by applying the "StyleTransfer" Core ML model to it.
    /// - Tag: CreateAlteredImage
    func createAlteredImage() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            do {
                self.styleIndexArray.setOnlyThisIndexToOne(self.styleIndex)
                
                let options = MLPredictionOptions()
                
                // If you leave `MLPredictionOptions` usesCPUOnly at its default value of `false`, Core ML may schedule its
                // work on either the GPU or Neural Engine (for A12+ devices). This sample leaves `usesCPUOnly` disabled
                // because its predications were tested to work well while executed off of the CPU.
                options.usesCPUOnly = false

                let input = StyleTransferModelInput(image: self.modelInputImage, index: self.styleIndexArray)
                let output = try AlteredImage.styleTransferModel.prediction(input: input, options: options)
                self.imageAlteringComplete(output.stylizedImage)
            } catch {
                self.imageAlteringFailed(error.localizedDescription)
            }
        }
    }
    
    /// - Tag: DisplayAlteredImage
    func imageAlteringComplete(_ createdImage: CVPixelBuffer) {
        guard fadeBetweenStyles else { return }
        modelOutputImage = createdImage
        visualizationNode.display(createdImage)
    }

    /// If altering the image failed, notify delegate the
    ///  to stop tracking this image.
    func imageAlteringFailed(_ errorDescription: String) {
        print("Error: Altering image failed - \(errorDescription).")
        self.delegate?.alteredImageLostTracking(self)
    }
}

/// Start altering an image using the next style if
///  an anchor for this altered image was already added.
extension AlteredImage: VisualizationNodeDelegate {
    /// - Tag: FadeAnimationComplete
    func visualizationNodeDidFinishFade(_ visualizationNode: VisualizationNode) {
        guard fadeBetweenStyles, anchor != nil else { return }
        selectNextStyle()
        createAlteredImage()
    }
}

/**
 Tells a delegate when image tracking failed.
  In this case, the delegate is the view controller.
 */
protocol AlteredImageDelegate: AnyObject {
    func alteredImageLostTracking(_ alteredImage: AlteredImage)
}
