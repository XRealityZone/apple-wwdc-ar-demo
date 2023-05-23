/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An interactive visualization a single x/y/z coordinate axis for use in placing the origin/anchor point of a scanned object.
*/

import SceneKit

class ObjectOriginAxis: SCNNode {
    
    let axis: Axis
    
    private var flashTimer: Timer?
    private var flashDuration = 0.1
    
    // Indicates whether this axis is currently in a highlighted state.
    // If so, the view displays a white axis.
    var isHighlighted: Bool = false {
        didSet {
            let emissionColor = isHighlighted ? UIColor.white : UIColor.black
            childNodes.forEach { $0.geometry?.materials.first?.emission.contents = emissionColor }
        }
    }
    
    func flash() {
        self.isHighlighted = true
        
        self.flashTimer?.invalidate()
        self.flashTimer = Timer.scheduledTimer(withTimeInterval: flashDuration, repeats: false) { _ in
            self.isHighlighted = false
        }
    }
    
    // MARK: - Initializers
    
    init(axis: Axis, length: Float, thickness: Float, radius: CGFloat, handleSize: CGFloat) {
        self.axis = axis
        super.init()
        
        var color: UIColor
        var texture: UIImage?
        var dimensions: SIMD3<Float>
        let position = axis.normal * (length / 2.0)
        let axisHandlePosition = axis.normal * length
        
        switch axis {
        case .x:
            color = UIColor.red
            texture = #imageLiteral(resourceName: "handle_red")
            dimensions = SIMD3<Float>(length, thickness, thickness)
        case .y:
            color = UIColor.green
            texture = #imageLiteral(resourceName: "handle_green")
            dimensions = SIMD3<Float>(thickness, length, thickness)
        case .z:
            color = UIColor.blue
            texture = #imageLiteral(resourceName: "handle_blue")
            dimensions = SIMD3<Float>(thickness, thickness, length)
        }
        
        let axisGeo = SCNBox(width: CGFloat(dimensions.x),
                             height: CGFloat(dimensions.y),
                             length: CGFloat(dimensions.z),
                             chamferRadius: radius)
        axisGeo.materials = [SCNMaterial.material(withDiffuse: color)]
        let axis = SCNNode(geometry: axisGeo)
        
        let axisHandleGeo = SCNPlane(width: handleSize, height: handleSize)
        axisHandleGeo.materials = [SCNMaterial.material(withDiffuse: texture, respondsToLighting: false)]
        let axisHandle = SCNNode(geometry: axisHandleGeo)
        axisHandle.constraints = [SCNBillboardConstraint()]
        
        axis.simdPosition = position
        axisHandle.simdPosition = axisHandlePosition
        
        // Increase the axis handle geometry's bounding box that is used for hit testing to make it easier to hit.
        let min = axisHandle.boundingBox.min
        let max = axisHandle.boundingBox.max
        let padding = Float(handleSize) * 0.8
        axisHandle.boundingBox.min = SCNVector3(min.x - padding, min.y - padding, min.z - padding)
        axisHandle.boundingBox.max = SCNVector3(max.x + padding, max.y + padding, max.z + padding)
        
        addChildNode(axis)
        addChildNode(axisHandle)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
