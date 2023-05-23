/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An interactive visualization of x/y/z coordinate axes for use in placing the origin/anchor point of a scanned object.
*/

import Foundation
import SceneKit
import ARKit

// Instances of this class represent the origin of the scanned 3D object - both
// logically as well as visually (as an SCNNode).
class ObjectOrigin: SCNNode {
    
    static let movedOutsideBoxNotification = Notification.Name("ObjectOriginMovedOutsideBoundingBox")
    static let positionChangedNotification = Notification.Name("ObjectOriginPositionChanged")
    
    private let axisLength: Float = 1.0
    private let axisThickness: Float = 6.0 // Axis thickness in percent of length.
    
    private let axisSizeToObjectSizeRatio: Float = 0.25
    private let minAxisSize: Float = 0.05
    private let maxAxisSize: Float = 0.2
    
    private var xAxis: ObjectOriginAxis!
    private var yAxis: ObjectOriginAxis!
    private var zAxis: ObjectOriginAxis!
    
    private var customModel: SCNNode?
    
    private var currentAxisDrag: PlaneDrag?
    private var currentPlaneDrag: PlaneDrag?
    
    private var sceneView: ARSCNView
    
    var positionHasBeenAdjustedByUser: Bool = false
    
    /// Variables related to current snapping state
    internal var isSnappedToSide = false
    internal var isSnappedToBottomCenter = false
    internal var isSnappedTo90DegreeRotation = false
    internal var totalRotationSinceLastSnap: Float = 0
    
    var isDisplayingCustom3DModel: Bool {
        return customModel != nil
    }
    
    init(extent: SIMD3<Float>, _ sceneView: ARSCNView) {
        self.sceneView = sceneView
        super.init()
        
        let length = axisLength
        let thickness = (axisLength / 100.0) * axisThickness
        let radius = CGFloat(axisThickness / 2.0)
        let handleSize = CGFloat(axisLength / 4)
        
        xAxis = ObjectOriginAxis(axis: .x, length: length, thickness: thickness, radius: radius,
                                 handleSize: handleSize)
        yAxis = ObjectOriginAxis(axis: .y, length: length, thickness: thickness, radius: radius,
                                 handleSize: handleSize)
        zAxis = ObjectOriginAxis(axis: .z, length: length, thickness: thickness, radius: radius,
                                 handleSize: handleSize)
        
        addChildNode(xAxis)
        addChildNode(yAxis)
        addChildNode(zAxis)
        
        set3DModel(ViewController.instance?.modelURL, extentForScaling: extent)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.scanningStateChanged(_:)),
                                               name: Scan.stateChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.boundingBoxExtentChanged(_:)),
                                               name: BoundingBox.extentChangedNotification, object: nil)
        isHidden = true
    }
    
    func set3DModel(_ url: URL?, extentForScaling: SIMD3<Float>?=nil) {
        customModel?.removeFromParentNode()
        customModel = nil
        
        if let url = url, let model = load3DModel(from: url) {
            ViewController.instance?.sceneView.prepare([model], completionHandler: { _ in
                self.addChildNode(model)
            })
            customModel = model
            
            xAxis.displayNodeHierarchyOnTop(true)
            yAxis.displayNodeHierarchyOnTop(true)
            zAxis.displayNodeHierarchyOnTop(true)
        } else {
            xAxis.displayNodeHierarchyOnTop(false)
            yAxis.displayNodeHierarchyOnTop(false)
            zAxis.displayNodeHierarchyOnTop(false)
        }
        
        adjustToExtent(extentForScaling)
    }
    
    @objc
    func boundingBoxExtentChanged(_ notification: Notification) {
        guard let boundingBox = notification.object as? BoundingBox else { return }
        self.adjustToExtent(boundingBox.extent)
    }
    
    func adjustToExtent(_ extent: SIMD3<Float>?) {
        guard let extent = extent else {
            self.simdScale = [1.0, 1.0, 1.0]
            xAxis.simdScale = [1.0, 1.0, 1.0]
            yAxis.simdScale = [1.0, 1.0, 1.0]
            zAxis.simdScale = [1.0, 1.0, 1.0]
            return
        }
        
        // By default the origin's scale is 1x.
        self.simdScale = [1.0, 1.0, 1.0]
        
        // Compute a good scale for the axes based on the extent of the bouning box,
        // but stay within a reasonable range.
        var axesScale = min(extent.x, extent.y, extent.z) * axisSizeToObjectSizeRatio
        axesScale = max(min(axesScale, maxAxisSize), minAxisSize)
        
        // Adjust the scale of the axes (not the origin itself!)
        xAxis.simdScale = [1.0, 1.0, 1.0] * axesScale
        yAxis.simdScale = [1.0, 1.0, 1.0] * axesScale
        zAxis.simdScale = [1.0, 1.0, 1.0] * axesScale
        
        if let model = customModel {
            // Scale the origin such that the custom 3D model fits into the given extent.
            let modelExtent = model.boundingSphere.radius * 2
            let originScale = min(extent.x, extent.y, extent.z) / modelExtent
            
            // Scale the origin itself, so that the scale will be preserved in the *.arobject file.
            self.simdScale = [1.0, 1.0, 1.0] * originScale
            
            // Correct the scale of the axes to be the same size as before
            xAxis.simdScale *= (1 / originScale)
            yAxis.simdScale *= (1 / originScale)
            zAxis.simdScale *= (1 / originScale)
        }
    }
    
    func updateScale(_ scale: Float) {
        // If a 3D model is being displayed, users should be able to change the scale
        // of the origin. This ensures that the scale at which the 3D model is displayed
        // will be preserved in the *.arobject file.
        if isDisplayingCustom3DModel {
            self.simdScale *= SIMD3<Float>(repeating: scale)
            
            // Correct the scale of the axes to be displayed at the same size as before.
            xAxis.simdScale *= (1 / scale)
            yAxis.simdScale *= (1 / scale)
            zAxis.simdScale *= (1 / scale)
        }
    }
    
    func startAxisDrag(screenPos: CGPoint) {
        guard let camera = sceneView.pointOfView else { return }
    
        // Check if the user is starting the drag on one of the axes. If so, drag along that axis.
        let hitResults = sceneView.hitTest(screenPos, options: [
            .rootNode: self,
            .boundingBoxOnly: true])
        
        for result in hitResults {
            if let hitAxis = result.node.parent as? ObjectOriginAxis {
                hitAxis.isHighlighted = true
                
                let worldAxis = hitAxis.simdConvertVector(hitAxis.axis.normal, to: nil)
                let worldPosition = hitAxis.simdConvertVector([0, 0, 0], to: nil)
                let hitAxisNormalInWorld = normalize(worldAxis - worldPosition)

                let dragRay = Ray(origin: self.simdWorldPosition, direction: hitAxisNormalInWorld)
                let transform = dragPlaneTransform(for: dragRay, cameraPos: camera.simdWorldPosition)
                
                var offset = SIMD3<Float>()
                if let hitPos = sceneView.unprojectPointLocal(screenPos, ontoPlane: transform) {
                    // Project the result onto the plane's X axis & transform into world coordinates.
                    let posOnPlaneXAxis = SIMD4<Float>(hitPos.x, 0, 0, 1)
                    let worldPosOnPlaneXAxis = transform * posOnPlaneXAxis

                    offset = self.simdWorldPosition - worldPosOnPlaneXAxis.xyz
                }
                
                currentAxisDrag = PlaneDrag(planeTransform: transform, offset: offset)
                positionHasBeenAdjustedByUser = true
                return
            }
        }
    }
    
    func updateAxisDrag(screenPos: CGPoint) {
        guard let drag = currentAxisDrag else { return }
        
        if let hitPos = sceneView.unprojectPointLocal(screenPos, ontoPlane: drag.planeTransform) {
            // Project the result onto the plane's X axis & transform into world coordinates.
            let posOnPlaneXAxis = SIMD4<Float>(hitPos.x, 0, 0, 1)
            let worldPosOnPlaneXAxis = drag.planeTransform * posOnPlaneXAxis

            self.simdWorldPosition = worldPosOnPlaneXAxis.xyz + drag.offset
            
            if customModel == nil {
                // Snap origin to any side of the bounding box and to the bottom center.
                snapToBoundingBoxSide()
            }

            NotificationCenter.default.post(name: ObjectOrigin.positionChangedNotification, object: self)

            if isOutsideBoundingBox {
                NotificationCenter.default.post(name: ObjectOrigin.movedOutsideBoxNotification, object: self)
            }
        }
    }
    
    func endAxisDrag() {
        currentAxisDrag = nil
        xAxis.isHighlighted = false
        yAxis.isHighlighted = false
        zAxis.isHighlighted = false
    }
    
    func startPlaneDrag(screenPos: CGPoint) {
        // Reposition the origin in the XZ-plane.
        let dragPlane = self.simdWorldTransform
        var offset = SIMD3<Float>(repeating: 0)
        if let hitPos = sceneView.unprojectPoint(screenPos, ontoPlane: dragPlane) {
            offset = self.simdWorldPosition - hitPos
        }
        self.currentPlaneDrag = PlaneDrag(planeTransform: dragPlane, offset: offset)
        positionHasBeenAdjustedByUser = true
    }
    
    func updatePlaneDrag(screenPos: CGPoint) {
        guard let drag = currentPlaneDrag else { return }
        
        if let hitPos = sceneView.unprojectPoint(screenPos, ontoPlane: drag.planeTransform) {
            self.simdWorldPosition = hitPos + drag.offset
            
            if customModel == nil {
                snapToBoundingBoxSide()
            }
            snapToBoundingBoxCenter()

            NotificationCenter.default.post(name: ObjectOrigin.positionChangedNotification, object: self)
            
            if isOutsideBoundingBox {
                NotificationCenter.default.post(name: ObjectOrigin.movedOutsideBoxNotification, object: self)
            }
        }
    }
    
    func endPlaneDrag() {
        currentPlaneDrag = nil
        isSnappedToSide = false
        isSnappedToBottomCenter = false
    }
    
    func flashOrReposition(screenPos: CGPoint) {
        // Check if the user tapped on one of the axes. If so, highlight it.
        let hitResults = sceneView.hitTest(screenPos, options: [
            .rootNode: self,
            .boundingBoxOnly: true])
        
        for result in hitResults {
            if let hitAxis = result.node.parent as? ObjectOriginAxis {
                hitAxis.flash()
                return
            }
        }
        
        // If no axis was hit, reposition the origin in the XZ-plane.
        if let hitPos = sceneView.unprojectPoint(screenPos, ontoPlane: self.simdWorldTransform) {
            self.simdWorldPosition = hitPos
            
            if isOutsideBoundingBox {
                NotificationCenter.default.post(name: ObjectOrigin.movedOutsideBoxNotification, object: self)
            }
        }
    }
    
    var isOutsideBoundingBox: Bool {
        guard let boundingBox = self.parent as? BoundingBox else { return true }
        
        let threshold = SIMD3<Float>(repeating: 0.002)
        let extent = boundingBox.extent + threshold
        
        let pos = simdPosition
        return pos.x < -extent.x / 2 || pos.y < -extent.y / 2 || pos.z < -extent.z / 2 ||
            pos.x > extent.x / 2 || pos.y > extent.y / 2 || pos.z > extent.z / 2
    }
    
    @objc
    private func scanningStateChanged(_ notification: Notification) {
        guard let state = notification.userInfo?[Scan.stateUserInfoKey] as? Scan.State else { return }
        switch state {
        case .ready, .defineBoundingBox, .scanning:
            self.isHidden = true
        case .adjustingOrigin:
            self.isHidden = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func isPartOfCustomModel(_ node: SCNNode) -> Bool {
        if node == customModel {
            return true
        }
        
        if let parent = node.parent {
            return isPartOfCustomModel(parent)
        }
        
        return false
    }
}
