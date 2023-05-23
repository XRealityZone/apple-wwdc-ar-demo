/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Useful extensions to make the code more readable.
*/

import Foundation
import RealityKit

extension Entity {
    var color: SimpleMaterial.Color? {
        get {
            if let model = components[ModelComponent.self] as? ModelComponent,
                let color = (model.materials.first as? SimpleMaterial)?.tintColor {
                return color
            }
            return nil
        }
        set {
            if var model = components[ModelComponent.self] as? ModelComponent {
                if let color = newValue {
                    model.materials = [SimpleMaterial(color: color, isMetallic: false)]
                } else {
                    model.materials = []
                }
                components[ModelComponent.self] = model
            }
        }
    }
}

extension simd_float4x4 {
    // Note to ourselves: This is the implementation from AREulerAnglesFromMatrix.
    // Ideally, this would be RealityKit API when this sample gets published.
    var eulerAngles: SIMD3<Float> {
        var angles: SIMD3<Float> = .zero
        
        if columns.2.y >= 1.0 - .ulpOfOne * 10 {
            angles.x = -.pi / 2
            angles.y = 0
            angles.z = atan2(-columns.0.z, -columns.1.z)
        } else if columns.2.y <= -1.0 + .ulpOfOne * 10 {
            angles.x = -.pi / 2
            angles.y = 0
            angles.z = atan2(columns.0.z, columns.1.z)
        } else {
            angles.x = asin(-columns.2.y)
            angles.y = atan2(columns.2.x, columns.2.z)
            angles.z = atan2(columns.0.y, columns.1.y)
        }
        
        return angles
    }
}
