/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ReckoningLevel
*/

import Combine
import RealityKit

protocol LoadedEntity {
    associatedtype LoadOutput
    static func loadAsync() -> AnyPublisher<LoadOutput, Error>
}

final class ReckoningLevel: LoadedEntity, GameResettable {
    
    var field: FieldEntity?
    
    static func loadPlacementUIAsync() -> AnyPublisher<Entity, Error> {
        return PlacementUIEntity.loadAsync()
            .map { placementUI in
                ReckoningLevel.shadows().forEach { placementUI.addChild($0) }
                return placementUI
            }
            .eraseToAnyPublisher()
    }

    static func loadBallAndPinsAsync() -> AnyPublisher<(BallEntity, (PinEntity, PinEntity)), Error> {
        return BallEntity.loadAsync()
            .zip(PinEntity.loadAsync())
            .eraseToAnyPublisher()
    }

    static func loadRemotesAndTargetsAsync() -> AnyPublisher<Void, Error> {
        return RemoteEntity.loadAsync()
            .zip(TargetEntity.loadAsync())
            .map { _ in return }
            .eraseToAnyPublisher()
    }

    static func loadAsync() -> AnyPublisher<ReckoningLevel, Error> {
        return FieldEntity.loadAsync()
            .zip(loadBallAndPinsAsync(),
                 loadRemotesAndTargetsAsync(),
                 BeamOfLightEntity.loadAsync())
            .map { field, ballAndPins, _, beamOfLight -> ReckoningLevel in
                ballAndPins.0.isEnabled = false
                field.addChild(ballAndPins.0)
                field.children.append(contentsOf: PinEntity.loadPins(origin: field))

                let beamOne = beamOfLight.clone(with: .teamA)
                beamOne.transform.translation = SIMD3<Float>(x: 0, y: 0, z: Team.teamA.zSign * 1.7)
                beamOne.transform.rotation = simd_quatf(angle: .pi, axis: [0.0, 1.0, 0.0])
                let beamTwo = beamOfLight.clone(with: .teamB)
                beamTwo.transform.translation = SIMD3<Float>(x: 0, y: 0, z: Team.teamB.zSign * 1.7)
                field.children.append(contentsOf: [beamOne, beamTwo])

                field.children.append(contentsOf: shadows())
                field.prepareToShowField()
                let spectatorListener = SpectatorListenerEntity()
                spectatorListener.transform.translation = [5, 0, 0]
                spectatorListener.transform.rotation = simd_quatf(angle: .pi * 0.5, axis: [0.0, 1.0, 0.0])
                field.addChild(spectatorListener)
                let level = ReckoningLevel(field: field)
                return level
            }
            .eraseToAnyPublisher()
        }
    
    private static func shadows() -> [Entity] {

        let lightShineTarget = SIMD3<Float>(0, 0, 0) // a point in front of the pins toward the center of the court
        
        // calculate where the light should go by parameterizing its position along a ray from
        // the target point on the field to a target point above the field, so we can scrub along that ray

        let lightPosition: SIMD3<Float> = SIMD3<Float>(0.7279, 2, 0.0 ) // corresponds to 70 degree angle
        let shadowCastingLight = DirectionalLight()
        shadowCastingLight.name = "shadowCastingLight"
        shadowCastingLight.light = DirectionalLightComponent(color: .white, intensity: 2145.7078, isRealWorldProxy: true)
        var newDistance: Float = 18.0            // Full court distance works for all full court scales
        if UserSettings.isTableTop {
            newDistance = 0.85                  // Table Top Distance works for all table top scales
        }
        shadowCastingLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: newDistance)
        shadowCastingLight.position = lightPosition
        shadowCastingLight.look(at: lightShineTarget, from: shadowCastingLight.position, relativeTo: nil)
        if UserSettings.visualMode == .cosmic {
            shadowCastingLight.isEnabled = false
        }

        return [shadowCastingLight]
    }

    private init(field: FieldEntity) {
        self.field = field
    }

    static func emptyLevel() -> ReckoningLevel {
        return ReckoningLevel(field: FieldEntity())
    }
    
    func gameReset() {
        guard let field = self.field else { return }
        field.gameReset()
    }

}
