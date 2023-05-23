/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that checks images for rectangles.
*/

import UIKit
import Vision
import CoreImage

/// - Tag: RectangleDetector
class RectangleDetector {
    
    private var currentCameraImage: CVPixelBuffer!
    
    private var updateTimer: Timer?
    
    /// The number of times per second to check for rectangles.
    /// - Tag: UpdateInterval
    private var updateInterval: TimeInterval = 0.1
    
    /// - Tag: IsBusy
    private var isBusy = false
    
    weak var delegate: RectangleDetectorDelegate?
    
    /// - Tag: InitializeVisionTimer
    init() {
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            if let capturedImage = ViewController.instance?.sceneView.session.currentFrame?.capturedImage {
                self?.search(in: capturedImage)
            }
        }
    }

    /// Search for rectangles in the camera's pixel buffer,
    ///  if a search is not already running.
    /// - Tag: SerializeVision
	private func search(in pixelBuffer: CVPixelBuffer) {
        guard !isBusy else { return }
        isBusy = true
 
        // Remember the current image.
        currentCameraImage = pixelBuffer
        
        // Note that the pixel buffer's orientation doesn't change even when the device rotates.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        // Create a Vision rectangle detection request for running on the GPU.
        let request = VNDetectRectanglesRequest { request, error in
            self.completedVisionRequest(request, error: error)
        }
        
        // Look only for one rectangle at a time.
        request.maximumObservations = 1
        
        // Require rectangles to be reasonably large.
        request.minimumSize = 0.25
        
        // Require high confidence for detection results.
        request.minimumConfidence = 0.90
        
        // Ignore rectangles with a too uneven aspect ratio.
        request.minimumAspectRatio = 0.3
        
        // Ignore rectangles that are skewed too much.
        request.quadratureTolerance = 20
        
        // You leverage the `usesCPUOnly` flag of `VNRequest` to decide whether your Vision requests are processed on the CPU or GPU.
        // This sample disables `usesCPUOnly` because rectangle detection isn't very taxing on the GPU. You may benefit by enabling
        // `usesCPUOnly` if your app does a lot of rendering, or runs a complicated neural network.
        request.usesCPUOnly = false
        
		DispatchQueue.global().async {
            do {
                try handler.perform([request])
            } catch {
                print("Error: Rectangle detection failed - vision request failed.")
                self.isBusy = false
            }
		}
	}
	
    /// Check for a rectangle result.
    /// If one is found, crop the camera image and correct its perspective.
    /// - Tag: CropCameraImage
    private func completedVisionRequest(_ request: VNRequest?, error: Error?) {
        defer {
            isBusy = false
        }
        // Only proceed if a rectangular image was detected.
        guard let rectangle = request?.results?.first as? VNRectangleObservation else {
            guard let error = error else { return }
            print("Error: Rectangle detection failed - Vision request returned an error. \(error.localizedDescription)")
            return
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            print("Error: Rectangle detection failed - Could not create perspective correction filter.")
            return
        }
        let width = CGFloat(CVPixelBufferGetWidth(currentCameraImage))
        let height = CGFloat(CVPixelBufferGetHeight(currentCameraImage))
        let topLeft = CGPoint(x: rectangle.topLeft.x * width, y: rectangle.topLeft.y * height)
        let topRight = CGPoint(x: rectangle.topRight.x * width, y: rectangle.topRight.y * height)
        let bottomLeft = CGPoint(x: rectangle.bottomLeft.x * width, y: rectangle.bottomLeft.y * height)
        let bottomRight = CGPoint(x: rectangle.bottomRight.x * width, y: rectangle.bottomRight.y * height)
        
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        let ciImage = CIImage(cvPixelBuffer: currentCameraImage).oriented(.up)
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let perspectiveImage: CIImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else {
            print("Error: Rectangle detection failed - perspective correction filter has no output image.")
            return
        }
        delegate?.rectangleFound(rectangleContent: perspectiveImage)
    }
}

protocol RectangleDetectorDelegate: AnyObject {
	func rectangleFound(rectangleContent: CIImage)
}
