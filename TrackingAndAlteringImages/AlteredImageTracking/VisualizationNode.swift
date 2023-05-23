/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A SceneKit node that fades between two images.
*/

import Foundation
import SceneKit
import ARKit

class VisualizationNode: SCNNode {

    /// The images to fade between.
    /// - Tag: VisualizationNode
    private let currentImage: SCNNode
    private let previousImage: SCNNode

    /// The duration of the fade animation, in seconds.
    private let fadeDuration = 1.0

    /// An object to notify of fade animation completion.
    weak var delegate: VisualizationNodeDelegate?
    
    /**
     Create a plane geometry for the current and previous altered images sized to the argument
     size, and initialize them with transparent material. Because `SCNPlane` is defined in the
     XY-plane, but `ARImageAnchor` is defined in the XZ plane, you rotate by 90 degrees to match.
     */
    init(_ size: CGSize) {
        currentImage = createPlaneNode(size: size, rotation: -.pi / 2, contents: UIColor.clear)
        previousImage = createPlaneNode(size: size, rotation: -.pi / 2, contents: UIColor.clear)
        
        super.init()
        
        addChildNode(currentImage)
        addChildNode(previousImage)
    }
    
    /// Assigns a new current image and fades from the previous image to it.
    /// - Tag: ImageFade
    func display(_ alteredImage: CVPixelBuffer) {
        
        // Put the previous image on the second plane and
        //  update the current plane's texture with the given stylized image.
        previousImage.geometry?.firstMaterial?.diffuse.contents = currentImage.geometry?.firstMaterial?.diffuse.contents
        currentImage.geometry?.firstMaterial?.diffuse.contents = alteredImage.toCGImage()
        
        // Start by displaying the previous image.
        currentImage.opacity = 0.0
        previousImage.opacity = 1.0
        
        // Fade between the two images.
        SCNTransaction.begin()
        SCNTransaction.animationDuration = fadeDuration
        currentImage.opacity = 1.0
        previousImage.opacity = 0.0
        SCNTransaction.completionBlock = {
            self.delegate?.visualizationNodeDidFinishFade(self)
        }
        SCNTransaction.commit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Tells a delegate when the fade animation is done.
/// In this case, the delegate is an AlteredImage object.
protocol VisualizationNodeDelegate: AnyObject {
    func visualizationNodeDidFinishFade(_ visualizationNode: VisualizationNode)
}
