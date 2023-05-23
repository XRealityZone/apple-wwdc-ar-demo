/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PlacementUIEntity
*/

import Combine
import RealityKit

final class PlacementUIEntity: Entity, LoadedEntity {

    static func loadAsync() -> AnyPublisher<PlacementUIEntity, Error> {
        return Entity.loadAsync(named: "court_placement")
            .map { entity -> PlacementUIEntity in
                let placementUI = PlacementUIEntity()
                placementUI.addChild(entity)
                placementUI.configure()
                return placementUI
            }
            .eraseToAnyPublisher()
    }
    
    private func configure() {
        self.name = "PlacementUI"
        self.transform = Transform(translation: SIMD3<Float>(0, -Constants.wallWidth, 0))
    }

}
