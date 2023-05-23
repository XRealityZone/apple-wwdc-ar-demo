/*
See LICENSE folder for this sample’s licensing information.

Abstract:
TransformMemoryComponent
*/

import os.log
import RealityKit

struct TransformMemoryComponent: Component {
    let transform: Transform
}

protocol HasTransformMemory where Self: HasTransform {}

extension HasTransformMemory {
    var memorizedTransform: Transform? {
        return components[TransformMemoryComponent.self]?.transform
    }
}

extension Entity: HasTransformMemory {

    func memorizeCurrentTransform() {
        components[TransformMemoryComponent.self] = TransformMemoryComponent(transform: transform)
    }

    func restoreToMemorizedTransform() {
        guard let memorized = memorizedTransform else { return }
        transform = memorized
    }

}
