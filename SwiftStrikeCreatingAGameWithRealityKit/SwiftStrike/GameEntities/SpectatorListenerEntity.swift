/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SpectatorListenerEntity
*/

import RealityKit

struct SpectatorListenerComponent: Component {}

extension SpectatorListenerComponent: Codable {}

final class SpectatorListenerEntity: Entity, HasModel {

    required init() {
        super.init()
        name = "SpectatorListener"
        components[SpectatorListenerComponent.self] = SpectatorListenerComponent()
        if UserSettings.showSpectatorListenerPosition {
            self.model = SpectatorListenerEntity.createModel()
        } else {
            self.model = nil
        }
    }

    static func createModel() -> ModelComponent {
        return ModelComponent(mesh: MeshResource.generateBox(size: 0.2),
                              materials: [SimpleMaterial(color: .purple, isMetallic: false)])
    }

}
