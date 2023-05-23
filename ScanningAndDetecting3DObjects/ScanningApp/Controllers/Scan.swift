/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Manages the major steps in scanning an object.
*/

import Foundation
import UIKit
import ARKit

class Scan {
    
    static let stateChangedNotification = Notification.Name("ScanningStateChanged")
    static let stateUserInfoKey = "ScanState"
    static let objectCreationInterval: CFTimeInterval = 1.0
    
    enum State {
        case ready
        case defineBoundingBox
        case scanning
        case adjustingOrigin
    }
    
    // The current state the scan is in
    private var stateValue: State = .ready
    var state: State {
        get {
            return stateValue
        }
        set {
            // Check that preconditions for the state change are met.
            switch newValue {
            case .ready:
                break
            case .defineBoundingBox where !boundingBoxExists && !ghostBoundingBoxExists:
                print("Error: Ghost bounding box not yet created.")
                return
            case .scanning where !boundingBoxExists, .adjustingOrigin where !boundingBoxExists:
                print("Error: Bounding box not yet created.")
                return
            case .scanning where stateValue == .defineBoundingBox && !isReasonablySized,
                 .adjustingOrigin where stateValue == .scanning && !isReasonablySized:
                
                let title = "Scanned object too big or small"
                let message = """
                Each dimension of the bounding box should be at least 1 centimeters and not exceed 5 meters.
                In addition, the volume of the bounding box should be at least 500 cubic cm.
                Do you want to go back and adjust the bounding box of the scanned object?
                """
                let previousState = stateValue
                ViewController.instance?.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                    self.state = previousState
                }
            case .scanning:
                // When entering the scanning state, take a screenshot of the object to be scanned.
                // This screenshot will later be saved in the *.arobject file
                createScreenshot()
            case .adjustingOrigin where stateValue == .scanning && qualityIsLow:
                let title = "Not enough detail"
                let message = """
                This scan has not enough detail (it contains \(pointCloud.count) features - aim for at least \(Scan.minFeatureCount)).
                It is unlikely that a good reference object can be generated.
                Do you want to go back and continue the scan?
                """
                ViewController.instance?.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                    self.state = .scanning
                }
            case .adjustingOrigin where stateValue == .scanning:
                if let boundingBox = scannedObject.boundingBox, boundingBox.progressPercentage < 100 {
                    let title = "Scan not complete"
                    let message = """
                    The object was not scanned from all sides, scanning progress is \(boundingBox.progressPercentage)%.
                    It is likely that it won't detect from all angles.
                    Do you want to go back and continue the scan?
                    """
                    ViewController.instance?.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                        self.state = .scanning
                    }
                }
            default:
                break
            }
            // Apply the new state
            stateValue = newValue

            NotificationCenter.default.post(name: Scan.stateChangedNotification,
                                            object: self,
                                            userInfo: [Scan.stateUserInfoKey: self.state])
        }
    }
    
    var objectToManipulate: SCNNode? {
        if state == .adjustingOrigin {
            return scannedObject.origin
        } else {
            return scannedObject.eitherBoundingBox
        }
    }
    
    // The object which we want to scan
    private(set) var scannedObject: ScannedObject
    
    // The result of this scan, an ARReferenceObject
    private(set) var scannedReferenceObject: ARReferenceObject?
    
    // The node for visualizing the point cloud.
    private(set) var pointCloud: ScannedPointCloud
    
    private var sceneView: ARSCNView
    
    private var isBusyCreatingReferenceObject = false
    
    private(set) var screenshot = UIImage()
    
    private var hasWarnedAboutLowLight = false
    
    private var isFirstScan: Bool {
        return ViewController.instance?.referenceObjectToMerge == nil
    }
    
    static let minFeatureCount = 100
    
    init(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
        
        scannedObject = ScannedObject(sceneView)
        pointCloud = ScannedPointCloud()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationStateChanged(_:)),
                                               name: ViewController.appStateChangedNotification,
                                               object: nil)
        
        self.sceneView.scene.rootNode.addChildNode(self.scannedObject)
        self.sceneView.scene.rootNode.addChildNode(self.pointCloud)
    }
    
    deinit {
        self.scannedObject.removeFromParentNode()
        self.pointCloud.removeFromParentNode()
    }
    
    @objc
    private func applicationStateChanged(_ notification: Notification) {
        guard let appState = notification.userInfo?[ViewController.appStateUserInfoKey] as? ViewController.State else { return }
        switch appState {
        case .scanning:
            scannedObject.isHidden = false
            pointCloud.isHidden = false
        default:
            scannedObject.isHidden = true
            pointCloud.isHidden = true
        }
    }
    
    func didOneFingerPan(_ gesture: UIPanGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.boundingBox?.startSidePlaneDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.boundingBox?.updateSidePlaneDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.boundingBox?.endSidePlaneDrag()
            @unknown default:
                break
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.origin?.startAxisDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.origin?.updateAxisDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.origin?.endAxisDrag()
            @unknown default:
                break
            }
        }
    }
    
    func didTwoFingerPan(_ gesture: ThresholdPanGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible:
                break
            case .began:
                if gesture.numberOfTouches == 2 {
                    scannedObject.boundingBox?.startGroundPlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed where gesture.isThresholdExceeded:
                if gesture.numberOfTouches == 2 {
                    scannedObject.boundingBox?.updateGroundPlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed:
                break
            case .failed, .cancelled, .ended:
                scannedObject.boundingBox?.endGroundPlaneDrag()
            @unknown default:
                break
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible:
                break
            case .began:
                if gesture.numberOfTouches == 2 {
                    scannedObject.origin?.startPlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed where gesture.isThresholdExceeded:
                if gesture.numberOfTouches == 2 {
                    scannedObject.origin?.updatePlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed:
                break
            case .failed, .cancelled, .ended:
                scannedObject.origin?.endPlaneDrag()
            @unknown default:
                break
            }
        }
    }
    
    func didRotate(_ gesture: ThresholdRotationGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            if gesture.state == .changed {
                scannedObject.rotateOnYAxis(by: -Float(gesture.rotationDelta))
            }
        } else if state == .adjustingOrigin {
            if gesture.state == .changed {
                scannedObject.origin?.rotateWithSnappingOnYAxis(by: -Float(gesture.rotationDelta))
            }
        }
    }
    
    func didLongPress(_ gesture: UILongPressGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.boundingBox?.startSideDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.boundingBox?.updateSideDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.boundingBox?.endSideDrag()
            @unknown default:
                break
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.origin?.startAxisDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.origin?.updateAxisDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.origin?.endAxisDrag()
            @unknown default:
                break
            }
        }
    }
    
    func didTap(_ gesture: UITapGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            if gesture.state == .ended {
                scannedObject.createOrMoveBoundingBox(screenPos: gesture.location(in: sceneView))
            }
        } else if state == .adjustingOrigin {
            if gesture.state == .ended {
                scannedObject.origin?.flashOrReposition(screenPos: gesture.location(in: sceneView))
            }
        }
    }
    
    func didPinch(_ gesture: ThresholdPinchGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible, .began:
                break
            case .changed where gesture.isThresholdExceeded:
                scannedObject.scaleBoundingBox(scale: gesture.scale)
                gesture.scale = 1
            case .changed:
                break
            case .failed, .cancelled, .ended:
                break
            @unknown default:
                break
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible, .began:
                break
            case .changed where gesture.isThresholdExceeded:
                scannedObject.origin?.updateScale(Float(gesture.scale))
                gesture.scale = 1
            case .changed, .failed, .cancelled, .ended:
                break
            @unknown default:
                break
            }
        }
    }
    
    func updateOnEveryFrame(_ frame: ARFrame) {
        if state == .ready || state == .defineBoundingBox {
            if let points = frame.rawFeaturePoints {
                // Automatically adjust the size of the bounding box.
                self.scannedObject.fitOverPointCloud(points)
            }
        }
        
        if state == .ready || state == .defineBoundingBox || state == .scanning {
            
            if let lightEstimate = frame.lightEstimate, lightEstimate.ambientIntensity < 500, !hasWarnedAboutLowLight, isFirstScan {
                hasWarnedAboutLowLight = true
                let title = "Too dark for scanning"
                let message = "Consider moving to an environment with more light."
                ViewController.instance?.showAlert(title: title, message: message)
            }
            
            // Try a preliminary creation of the reference object based off the current
            // bounding box & update the point cloud visualization based on that.
            if let boundingBox = scannedObject.eitherBoundingBox {
                // Note: Create a new preliminary reference object in regular intervals.
                //       Creating the reference object is asynchronous and likely
                //       takes some time to complete. Avoid calling it again before
                //       enough time has passed and while we still wait for the
                //       previous call to complete.
                let now = CACurrentMediaTime()
                if now - timeOfLastReferenceObjectCreation > Scan.objectCreationInterval, !isBusyCreatingReferenceObject {
                    timeOfLastReferenceObjectCreation = now
                    isBusyCreatingReferenceObject = true
                    sceneView.session.createReferenceObject(transform: boundingBox.simdWorldTransform,
                                                            center: SIMD3<Float>(),
                                                            extent: boundingBox.extent) { object, error in
                        if let referenceObject = object {
                            // Pass the feature points to the point cloud visualization.
                            self.pointCloud.update(with: referenceObject.rawFeaturePoints, localFor: boundingBox)
                        }
                        self.isBusyCreatingReferenceObject = false
                    }
                }
                
                // Update the point cloud with the current frame's points as well
                if let currentPoints = frame.rawFeaturePoints {
                    pointCloud.update(with: currentPoints)
                }
            }
        }
        
        // Update bounding box side coloring to visualize scanning coverage
        if state == .scanning {
            scannedObject.boundingBox?.highlightCurrentTile()
            scannedObject.boundingBox?.updateCapturingProgress()
        }
        
        scannedObject.updateOnEveryFrame()
        pointCloud.updateOnEveryFrame()
    }
    
    var timeOfLastReferenceObjectCreation = CACurrentMediaTime()
    
    var qualityIsLow: Bool {
        return pointCloud.count < Scan.minFeatureCount
    }
    
    var boundingBoxExists: Bool {
        return scannedObject.boundingBox != nil
    }
    
    var ghostBoundingBoxExists: Bool {
        return scannedObject.ghostBoundingBox != nil
    }
    
    var isReasonablySized: Bool {
        guard let boundingBox = scannedObject.boundingBox else {
            return false
        }
        
        // The bounding box should not be too small and not too large.
        // Note: 3D object detection is optimized for tabletop scenarios.
        let validSizeRange: ClosedRange<Float> = 0.01...5.0
        if validSizeRange.contains(boundingBox.extent.x) && validSizeRange.contains(boundingBox.extent.y) &&
            validSizeRange.contains(boundingBox.extent.z) {
            // Check that the volume of the bounding box is at least 500 cubic centimeters.
            let volume = boundingBox.extent.x * boundingBox.extent.y * boundingBox.extent.z
            return volume >= 0.0005
        }
        
        return false
    }
    
    /// - Tag: ExtractReferenceObject
    func createReferenceObject(completionHandler creationFinished: @escaping (ARReferenceObject?) -> Void) {
        guard let boundingBox = scannedObject.boundingBox, let origin = scannedObject.origin else {
            print("Error: No bounding box or object origin present.")
            creationFinished(nil)
            return
        }
        
        // Extract the reference object based on the position & orientation of the bounding box.
        sceneView.session.createReferenceObject(
            transform: boundingBox.simdWorldTransform,
            center: SIMD3<Float>(), extent: boundingBox.extent,
            completionHandler: { object, error in
                if let referenceObject = object {
                    // Adjust the object's origin with the user-provided transform.
                    self.scannedReferenceObject = referenceObject.applyingTransform(origin.simdTransform)
                    self.scannedReferenceObject!.name = self.scannedObject.scanName
                    
                    if let referenceObjectToMerge = ViewController.instance?.referenceObjectToMerge {
                        ViewController.instance?.referenceObjectToMerge = nil
                        
                        // Show activity indicator during the merge.
                        ViewController.instance?.showAlert(title: "", message: "Merging previous scan into this scan...", buttonTitle: nil)
                        
                        // Try to merge the object which was just scanned with the existing one.
                        self.scannedReferenceObject?.mergeInBackground(with: referenceObjectToMerge, completion: { (mergedObject, error) in

                            if let mergedObject = mergedObject {
                                self.scannedReferenceObject = mergedObject
                                ViewController.instance?.showAlert(title: "Merge successful",
                                                                   message: "The previous scan has been merged into this scan.", buttonTitle: "OK")
                                creationFinished(self.scannedReferenceObject)

                            } else {
                                print("Error: Failed to merge scans. \(error?.localizedDescription ?? "")")
                                let message = """
                                        Merging the previous scan into this scan failed. Please make sure that
                                        there is sufficient overlap between both scans and that the lighting
                                        environment hasn't changed drastically.
                                        Which scan do you want to use for testing?
                                        """
                                let thisScan = UIAlertAction(title: "Use This Scan", style: .default) { _ in
                                    creationFinished(self.scannedReferenceObject)
                                }
                                let previousScan = UIAlertAction(title: "Use Previous Scan", style: .default) { _ in
                                    self.scannedReferenceObject = referenceObjectToMerge
                                    creationFinished(self.scannedReferenceObject)
                                }
                                ViewController.instance?.showAlert(title: "Merge failed", message: message, actions: [thisScan, previousScan])
                            }
                        })
                    } else {
                        creationFinished(self.scannedReferenceObject)
                    }
                } else {
                    print("Error: Failed to create reference object. \(error!.localizedDescription)")
                    creationFinished(nil)
                }
            })
    }
    
    private func createScreenshot() {
        guard let frame = self.sceneView.session.currentFrame else {
            print("Error: Failed to create a screenshot - no current ARFrame exists.")
            return
        }

        var orientation: UIImage.Orientation = .right
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = .right
        case .portraitUpsideDown:
            orientation = .left
        case .landscapeLeft:
            orientation = .up
        case .landscapeRight:
            orientation = .down
        default:
            break
        }
        
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        if let cgimage = context.createCGImage(ciImage, from: ciImage.extent) {
            screenshot = UIImage(cgImage: cgimage, scale: 1.0, orientation: orientation)
        }
    }
}
